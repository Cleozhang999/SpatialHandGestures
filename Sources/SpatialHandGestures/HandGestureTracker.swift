#if os(visionOS)
import ARKit
import Observation
import simd

/// Runs ARKit hand tracking and feeds every update into a set of gesture detectors.
///
/// One tracker owns one `ARKitSession`, so an app that needs several gestures
/// shares a single hand-tracking stream instead of starting a session per gesture.
///
/// ```swift
/// @State private var gestures = HandGestureTracker(pinchHolds: [.thumbIndex, .thumbIndexMiddle])
///
/// RealityView { content in ... }
///     .task { await gestures.run() }
///     .onChange(of: gestures.isPraying) { _, praying in ... }
/// ```
///
/// Hand tracking only works in an immersive space, and the app's Info.plist needs an
/// `NSHandsTrackingUsageDescription` entry.
@MainActor
@Observable
public final class HandGestureTracker {
    public enum Event: Sendable, Equatable {
        /// An event from the pinch-hold detector at `index` in `pinchHolds`.
        case pinchHold(index: Int, PinchHoldDetector.Event)
        /// The prayer pose started (`true`) or ended (`false`).
        case prayer(Bool)
    }

    public enum State: Sendable, Equatable {
        case idle
        case running
        /// Hand tracking is not supported on this device, for example in the simulator.
        case unsupported
        case notAuthorized
        case failed(String)
    }

    /// The most recent pose of each hand. `nil` while a hand is not tracked.
    public private(set) var leftHand: HandPose?
    public private(set) var rightHand: HandPose?

    /// Whether both palms are pressed together.
    public private(set) var isPraying = false
    /// The pinch-hold detectors, in the order they were configured.
    public private(set) var pinchHolds: [PinchHoldDetector]
    public private(set) var state: State = .idle

    /// Called for every gesture event, on the main actor.
    @ObservationIgnored public var onEvent: ((Event) -> Void)?

    @ObservationIgnored private var prayer: PrayerDetector
    @ObservationIgnored private let session = ARKitSession()
    @ObservationIgnored private let handTracking = HandTrackingProvider()

    public init(
        pinchHolds: [PinchHoldDetector.Configuration] = [.thumbIndex],
        prayer: PrayerDetector.Configuration = .init()
    ) {
        self.pinchHolds = pinchHolds.map(PinchHoldDetector.init(configuration:))
        self.prayer = PrayerDetector(configuration: prayer)
    }

    /// Starts hand tracking and processes updates until the calling task is cancelled.
    ///
    /// Call this from a SwiftUI `.task` modifier so it stops when the view disappears.
    public func run() async {
        guard HandTrackingProvider.isSupported else {
            state = .unsupported
            return
        }
        let authorization = await session.requestAuthorization(for: [.handTracking])
        guard authorization[.handTracking] == .allowed else {
            state = .notAuthorized
            return
        }
        do {
            try await session.run([handTracking])
        } catch {
            state = .failed(error.localizedDescription)
            return
        }
        state = .running
        defer {
            session.stop()
            state = .idle
        }

        for await update in handTracking.anchorUpdates {
            let anchor = update.anchor
            let chirality: Chirality = anchor.chirality == .left ? .left : .right
            let pose = (update.event == .removed || !anchor.isTracked) ? nil : HandPose(anchor)
            process(pose, chirality: chirality, at: update.timestamp)
        }
    }

    private func process(_ pose: HandPose?, chirality: Chirality, at time: TimeInterval) {
        switch chirality {
        case .left: leftHand = pose
        case .right: rightHand = pose
        }

        for index in pinchHolds.indices {
            if let event = pinchHolds[index].update(pose, chirality: chirality, at: time) {
                onEvent?(.pinchHold(index: index, event))
            }
        }

        if let praying = prayer.update(left: leftHand, right: rightHand) {
            isPraying = praying
            onEvent?(.prayer(praying))
        }
    }
}

extension HandPose {
    /// Creates a pose from an ARKit hand anchor, keeping only tracked joints.
    public init?(_ anchor: HandAnchor) {
        guard let skeleton = anchor.handSkeleton else { return nil }
        var joints: [HandJoint: SIMD3<Float>] = [:]
        for joint in HandJoint.allCases {
            let skeletonJoint = skeleton.joint(joint.skeletonJointName)
            guard skeletonJoint.isTracked else { continue }
            let transform = anchor.originFromAnchorTransform * skeletonJoint.anchorFromJointTransform
            joints[joint] = SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        }
        self.init(chirality: anchor.chirality == .left ? .left : .right, joints: joints)
    }
}

extension HandJoint {
    var skeletonJointName: HandSkeleton.JointName {
        switch self {
        case .wrist: .wrist
        case .thumbTip: .thumbTip
        case .indexFingerTip: .indexFingerTip
        case .middleFingerTip: .middleFingerTip
        case .ringFingerTip: .ringFingerTip
        case .littleFingerTip: .littleFingerTip
        }
    }
}
#endif
