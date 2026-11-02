import simd

/// Which hand a pose belongs to.
public enum Chirality: String, Sendable, Hashable, CaseIterable {
    case left
    case right
}

/// The subset of hand joints the gesture detectors use.
public enum HandJoint: String, Sendable, Hashable, CaseIterable {
    case wrist
    case thumbTip
    case indexFingerTip
    case middleFingerTip
    case ringFingerTip
    case littleFingerTip
}

/// A platform-independent snapshot of one tracked hand.
///
/// Joint positions are in world space, in meters. A joint that is missing from
/// `joints` was not tracked in this frame.
public struct HandPose: Sendable, Equatable {
    public var chirality: Chirality
    public var joints: [HandJoint: SIMD3<Float>]

    public init(chirality: Chirality, joints: [HandJoint: SIMD3<Float>]) {
        self.chirality = chirality
        self.joints = joints
    }

    public subscript(joint: HandJoint) -> SIMD3<Float>? {
        joints[joint]
    }

    /// Returns `true` when every pair of the given joints is closer than `threshold`.
    ///
    /// Returns `false` if any of the joints is not tracked.
    public func jointsAreTouching(_ names: [HandJoint], within threshold: Float) -> Bool {
        let positions = names.compactMap { joints[$0] }
        guard positions.count == names.count, positions.count >= 2 else { return false }
        for i in positions.indices {
            for j in positions.indices where j > i {
                if simd_distance(positions[i], positions[j]) >= threshold { return false }
            }
        }
        return true
    }
}
