import Foundation
import CoreGraphics

@main struct MotionTests {
    static func main() {
        var motion = CursorMotion()
        func sample(_ x: Float, _ time: Double, pressed: Bool = false, touching: Bool = true, id: UInt8 = 1) -> CGPoint? {
            motion.update(x: x, y: 0, touching: touching, contactID: id, clicked: pressed, time: time, sensitivity: 1)
        }
        precondition(sample(0, 0) == nil)
        for i in 1...60 {
            precondition(sample(i % 2 == 0 ? 0.0005 : -0.0005, Double(i) / 120) == nil, "Stationary jitter should not move the pointer")
        }
        // Pressing shifts the finger, but must not turn a click into a drag.
        precondition(sample(0.03, 0.51, pressed: true) == nil)
        precondition(sample(0.04, 0.56, pressed: true) == nil)
        precondition(sample(0.04, 0.64, pressed: true) == nil)
        precondition(sample(0.045, 0.66, pressed: true) == nil)
        precondition(sample(0.07, 0.68, pressed: true) == nil, "Crossing drag threshold rebases without a jump")
        precondition((sample(0.09, 0.70, pressed: true)?.x ?? 0) > 0, "Deliberate drag must work")
        precondition(sample(0.06, 0.72) == nil, "Release wobble must be suppressed")
        precondition(sample(0.04, 0.75) == nil)
        precondition(sample(0.04, 0.80) == nil)
        precondition(sample(0.04, 0.82, touching: false) == nil)
        precondition(sample(-0.5, 0.84, id: 2) == nil, "Retouch must not jump")
        precondition(sample(0.5, 0.86, id: 2) == nil, "Corrupt position jump must be discarded")
        precondition(sample(0.6, 1.2, id: 2) == nil, "Input gaps must reset the baseline")
        motion.reset()
        precondition(sample(0.9, 1.3) == nil)

        func travel(rate: Int) -> Double {
            var filter = CursorMotion()
            var total = 0.0
            for i in 0...(rate + rate / 4) {
                let t = Double(i) / Double(rate)
                let x = Float(min(t, 1) * 0.2)
                total += Double(filter.update(x: x, y: 0, touching: true, contactID: 1, clicked: false, time: t, sensitivity: 1)?.x ?? 0)
            }
            return total
        }
        let slow = travel(rate: 60), fast = travel(rate: 120)
        precondition(abs(slow - 129) <= 1 && abs(fast - slow) <= 1, "Smoothing must preserve travel across input rates")
        print("Motion tests passed: jitter, press/release stability, intentional drag, retouch, gaps, outliers, and consistent travel at 60/120 Hz.")
    }
}
