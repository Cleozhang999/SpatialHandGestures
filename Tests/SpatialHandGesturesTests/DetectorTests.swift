import Testing
import simd
@testable import SpatialHandGestures

private func hand(_ chirality: Chirality, thumbToIndex: Float, wrist: SIMD3<Float> = .zero) -> HandPose {
    HandPose(chirality: chirality, joints: [
        .wrist: wrist,
        .thumbTip: wrist + [0, 0.1, 0],
        .indexFingerTip: wrist + [thumbToIndex, 0.1, 0],
        .middleFingerTip: wrist + [0.05, 0.1, 0],
    ])
}

@Suite struct PinchHoldDetectorTests {
    @Test func completesAfterHoldDuration() {
        var detector = PinchHoldDetector()
        #expect(detector.update(hand(.right, thumbToIndex: 0.01), chirality: .right, at: 0) == .began(.right))
        #expect(detector.update(hand(.right, thumbToIndex: 0.01), chirality: .right, at: 0.5) == nil)
        #expect(detector.update(hand(.right, thumbToIndex: 0.01), chirality: .right, at: 1.0) == .completed(.right, wristPosition: .zero))
    }

    @Test func firesOncePerHold() {
        var detector = PinchHoldDetector()
        _ = detector.update(hand(.right, thumbToIndex: 0.01), chirality: .right, at: 0)
        _ = detector.update(hand(.right, thumbToIndex: 0.01), chirality: .right, at: 1)
        #expect(detector.update(hand(.right, thumbToIndex: 0.01), chirality: .right, at: 3) == nil)
        #expect(detector.update(hand(.right, thumbToIndex: 0.05), chirality: .right, at: 4) == .released(.right))
        #expect(detector.update(hand(.right, thumbToIndex: 0.01), chirality: .right, at: 5) == .began(.right))
    }

    @Test func cancelsWhenFingersSeparateEarly() {
        var detector = PinchHoldDetector()
        _ = detector.update(hand(.left, thumbToIndex: 0.01), chirality: .left, at: 0)
        #expect(detector.update(hand(.left, thumbToIndex: 0.05), chirality: .left, at: 0.3) == .cancelled(.left))
        #expect(detector.phase == .idle)
    }

    @Test func cancelsWhenTrackingIsLost() {
        var detector = PinchHoldDetector()
        _ = detector.update(hand(.left, thumbToIndex: 0.01), chirality: .left, at: 0)
        #expect(detector.update(nil, chirality: .left, at: 0.3) == .cancelled(.left))
    }

    @Test func hysteresisAbsorbsJitter() {
        var detector = PinchHoldDetector()
        _ = detector.update(hand(.right, thumbToIndex: 0.019), chirality: .right, at: 0)
        // Slightly above the touch threshold but within the release hysteresis.
        #expect(detector.update(hand(.right, thumbToIndex: 0.022), chirality: .right, at: 0.5) == nil)
        #expect(detector.isPinching)
    }

    @Test func ignoresOtherHandWhileLocked() {
        var detector = PinchHoldDetector()
        _ = detector.update(hand(.right, thumbToIndex: 0.01), chirality: .right, at: 0)
        #expect(detector.update(hand(.left, thumbToIndex: 0.01), chirality: .left, at: 0.1) == nil)
        #expect(detector.update(nil, chirality: .left, at: 0.2) == nil)
        #expect(detector.phase == .holding(.right, since: 0))
    }

    @Test func respectsHandRestriction() {
        var detector = PinchHoldDetector(configuration: .init(hand: .left))
        #expect(detector.update(hand(.right, thumbToIndex: 0.01), chirality: .right, at: 0) == nil)
        #expect(detector.update(hand(.left, thumbToIndex: 0.01), chirality: .left, at: 0) == .began(.left))
    }

    @Test func threeFingerPinchNeedsMiddleFinger() {
        var detector = PinchHoldDetector(configuration: .thumbIndexMiddle)
        // Middle finger is 5 cm away from the thumb, so this is not a three-finger pinch.
        #expect(detector.update(hand(.right, thumbToIndex: 0.01), chirality: .right, at: 0) == nil)

        var pose = hand(.right, thumbToIndex: 0.01)
        pose.joints[.middleFingerTip] = pose[.thumbTip]! + [0, 0.01, 0]
        #expect(detector.update(pose, chirality: .right, at: 0) == .began(.right))
    }

    @Test func untrackedJointIsNotAPinch() {
        var detector = PinchHoldDetector()
        var pose = hand(.right, thumbToIndex: 0.01)
        pose.joints[.indexFingerTip] = nil
        #expect(detector.update(pose, chirality: .right, at: 0) == nil)
    }
}

@Suite struct PrayerDetectorTests {
    private func pair(gap: Float) -> (HandPose, HandPose) {
        (hand(.left, thumbToIndex: 0.05, wrist: [-gap / 2, 0, 0]),
         hand(.right, thumbToIndex: 0.05, wrist: [gap / 2, 0, 0]))
    }

    @Test func entersAndExitsWithHysteresis() {
        var detector = PrayerDetector()
        var (l, r) = pair(gap: 0.2)
        #expect(detector.update(left: l, right: r) == nil)

        (l, r) = pair(gap: 0.05)
        #expect(detector.update(left: l, right: r) == true)

        // Between enter (0.10) and exit (0.12): stays active.
        (l, r) = pair(gap: 0.11)
        #expect(detector.update(left: l, right: r) == nil)
        #expect(detector.isActive)

        (l, r) = pair(gap: 0.15)
        #expect(detector.update(left: l, right: r) == false)
    }

    @Test func endsWhenOneHandIsLost() {
        var detector = PrayerDetector()
        let (l, r) = pair(gap: 0.05)
        _ = detector.update(left: l, right: r)
        #expect(detector.update(left: l, right: nil) == false)
    }
}
