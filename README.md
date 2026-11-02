# SpatialHandGestures

Hand-tracking gestures for visionOS beyond the system tap and pinch:

- **Pinch and hold.** Thumb plus one or more finger tips held together for a set time. Either hand can trigger it, and detection locks onto whichever hand started.
- **Prayer pose.** Both palms pressed together.

The detectors are plain Swift value types with no ARKit dependency, so you can unit test them on a Mac, replay recorded hand data, or plug in another tracking source. `HandGestureTracker` connects them to ARKit on visionOS through a single shared `ARKitSession`.

## Requirements

- visionOS 2 or later for live hand tracking (macOS 14+ for the detectors alone)
- Swift 6
- An immersive space. ARKit only delivers hand anchors while one is open.
- `NSHandsTrackingUsageDescription` in your app's Info.plist

## Installation

```swift
.package(url: "https://github.com/Cleozhang999/SpatialHandGestures.git", from: "0.1.0")
```

## Usage

```swift
import SpatialHandGestures
import SwiftUI
import RealityKit

struct MeditationSpace: View {
    @State private var gestures = HandGestureTracker(pinchHolds: [.thumbIndex, .thumbIndexMiddle])

    var body: some View {
        RealityView { content in
            // ...
        }
        .task {
            gestures.onEvent = { event in
                switch event {
                case .pinchHold(index: 0, .completed(let hand, let wrist)):
                    print("\(hand) hand held a pinch at \(String(describing: wrist))")
                case .pinchHold(index: 1, .completed):
                    print("Three-finger hold")
                case .prayer(true):
                    print("Hands together")
                default:
                    break
                }
            }
            await gestures.run()
        }
    }
}
```

`gestures.isPraying`, `gestures.pinchHolds[i].phase`, `gestures.leftHand` and `gestures.rightHand` are observable, so SwiftUI views can read them directly.

### Without ARKit

```swift
var detector = PinchHoldDetector(configuration: .init(fingers: [.indexFingerTip], holdDuration: 0.5))
let pose = HandPose(chirality: .right, joints: [.thumbTip: [0, 0, 0], .indexFingerTip: [0.01, 0, 0]])
detector.update(pose, chirality: .right, at: 0)    // .began(.right)
detector.update(pose, chirality: .right, at: 0.5)  // .completed(.right, wristPosition: nil)
```

### Tuning

| Setting | Default | Meaning |
|---|---|---|
| `touchThreshold` | 2 cm | Joints closer than this count as touching |
| `releaseHysteresis` | 0.5 cm | Extra separation needed to end a pinch, so tracking jitter does not end it |
| `holdDuration` | 1 s | Time the pinch must be held |
| `PrayerDetector` `enterDistance` / `exitDistance` | 10 cm / 12 cm | Wrist-to-wrist and thumb-to-thumb distances |

## Testing

```bash
swift test
```

## License

MIT. See [LICENSE](LICENSE).
