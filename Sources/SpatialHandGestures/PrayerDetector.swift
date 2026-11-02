import simd

/// Detects both palms pressed together (a "prayer" or *gassho* pose).
///
/// The pose counts as active when the two wrists and the two thumb tips are each
/// closer than `enterDistance`. It stays active until either pair moves farther
/// than `exitDistance`, which keeps tracking jitter from toggling the state.
public struct PrayerDetector: Sendable {
    public struct Configuration: Sendable, Equatable {
        /// Distance in meters below which the hands count as together.
        public var enterDistance: Float
        /// Distance in meters above which the hands count as apart again.
        public var exitDistance: Float

        public init(enterDistance: Float = 0.10, exitDistance: Float = 0.12) {
            precondition(exitDistance >= enterDistance, "exitDistance must not be smaller than enterDistance")
            self.enterDistance = enterDistance
            self.exitDistance = exitDistance
        }
    }

    public var configuration: Configuration
    public private(set) var isActive = false

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    /// Feeds the latest poses of both hands into the detector.
    ///
    /// - Returns: The new value of `isActive` if it changed, otherwise `nil`.
    public mutating func update(left: HandPose?, right: HandPose?) -> Bool? {
        let newValue = evaluate(left: left, right: right)
        guard newValue != isActive else { return nil }
        isActive = newValue
        return newValue
    }

    public mutating func reset() {
        isActive = false
    }

    private func evaluate(left: HandPose?, right: HandPose?) -> Bool {
        guard let left, let right,
              let leftWrist = left[.wrist], let rightWrist = right[.wrist],
              let leftThumb = left[.thumbTip], let rightThumb = right[.thumbTip] else {
            return false
        }
        let threshold = isActive ? configuration.exitDistance : configuration.enterDistance
        return simd_distance(leftWrist, rightWrist) < threshold
            && simd_distance(leftThumb, rightThumb) < threshold
    }
}
