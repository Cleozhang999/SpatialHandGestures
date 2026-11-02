import Foundation
import simd

/// Detects a "pinch and hold" gesture: the thumb tip touching one or more finger tips
/// for at least `holdDuration` seconds.
///
/// The detector locks onto whichever hand starts the pinch, so the other hand is
/// ignored until that pinch is released or cancelled. A completed hold fires once;
/// the hand has to open again before another hold can begin.
///
/// The detector is a plain value type with no ARKit dependency. Feed it poses from
/// `HandGestureTracker`, from recorded data, or from tests.
public struct PinchHoldDetector: Sendable {
    public struct Configuration: Sendable, Equatable {
        /// The finger tips that must touch the thumb tip. They also have to touch each other.
        public var fingers: [HandJoint]
        /// Maximum distance between joints, in meters, to count as touching.
        public var touchThreshold: Float
        /// Extra distance, in meters, the joints must separate before a pinch counts as released.
        /// This keeps tracking jitter from ending a pinch early.
        public var releaseHysteresis: Float
        /// How long the pinch must be held, in seconds.
        public var holdDuration: TimeInterval
        /// Restricts detection to one hand. `nil` accepts either hand.
        public var hand: Chirality?

        public init(
            fingers: [HandJoint] = [.indexFingerTip],
            touchThreshold: Float = 0.02,
            releaseHysteresis: Float = 0.005,
            holdDuration: TimeInterval = 1.0,
            hand: Chirality? = nil
        ) {
            self.fingers = fingers
            self.touchThreshold = touchThreshold
            self.releaseHysteresis = releaseHysteresis
            self.holdDuration = holdDuration
            self.hand = hand
        }

        /// Thumb and index finger.
        public static let thumbIndex = Configuration(fingers: [.indexFingerTip])
        /// Thumb, index and middle finger together.
        public static let thumbIndexMiddle = Configuration(fingers: [.indexFingerTip, .middleFingerTip])
    }

    public enum Event: Sendable, Equatable {
        /// The fingers touched; the hold timer started.
        case began(Chirality)
        /// The fingers stayed together for `holdDuration`. `wristPosition` is where the hand was.
        case completed(Chirality, wristPosition: SIMD3<Float>?)
        /// The fingers separated, or tracking was lost, before the hold completed.
        case cancelled(Chirality)
        /// The fingers separated after a completed hold.
        case released(Chirality)
    }

    public enum Phase: Sendable, Equatable {
        case idle
        case holding(Chirality, since: TimeInterval)
        /// The hold completed and the hand has not opened yet.
        case completed(Chirality)
    }

    public var configuration: Configuration
    public private(set) var phase: Phase = .idle

    public init(configuration: Configuration = .thumbIndex) {
        self.configuration = configuration
    }

    /// Whether the fingers are currently pinched, whether or not the hold has completed.
    public var isPinching: Bool {
        phase != .idle
    }

    /// Feeds the latest pose of one hand into the detector.
    ///
    /// - Parameters:
    ///   - pose: The hand's pose, or `nil` if that hand lost tracking.
    ///   - chirality: Which hand `pose` belongs to. Needed so lost tracking can end a pinch.
    ///   - time: A monotonic timestamp in seconds.
    /// - Returns: The event this update caused, if any.
    public mutating func update(_ pose: HandPose?, chirality: Chirality, at time: TimeInterval) -> Event? {
        if let hand = configuration.hand, hand != chirality { return nil }

        switch phase {
        case .idle:
            guard let pose, isTouching(pose, threshold: configuration.touchThreshold) else { return nil }
            phase = .holding(chirality, since: time)
            return .began(chirality)

        case .holding(let activeHand, let start):
            guard activeHand == chirality else { return nil }
            guard let pose, isTouching(pose, threshold: releaseThreshold) else {
                phase = .idle
                return .cancelled(chirality)
            }
            guard time - start >= configuration.holdDuration else { return nil }
            phase = .completed(chirality)
            return .completed(chirality, wristPosition: pose[.wrist])

        case .completed(let activeHand):
            guard activeHand == chirality else { return nil }
            if let pose, isTouching(pose, threshold: releaseThreshold) { return nil }
            phase = .idle
            return .released(chirality)
        }
    }

    /// Clears any pinch in progress.
    public mutating func reset() {
        phase = .idle
    }

    private var releaseThreshold: Float {
        configuration.touchThreshold + configuration.releaseHysteresis
    }

    private func isTouching(_ pose: HandPose, threshold: Float) -> Bool {
        pose.jointsAreTouching([.thumbTip] + configuration.fingers, within: threshold)
    }
}
