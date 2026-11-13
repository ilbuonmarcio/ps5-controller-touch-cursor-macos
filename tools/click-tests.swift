import Foundation
import CoreGraphics

@main struct ClickTests {
    static func main() {
        var clicks = ClickSequence()
        let point = CGPoint(x: 100, y: 100)
        precondition(clicks.press(at: point, time: 0, interval: 0.5) == 1)
        precondition(clicks.release(at: point, time: 0.04, interval: 0.5) == 1)
        precondition(clicks.press(at: point, time: 0.12, interval: 0.5) == 2)
        precondition(clicks.release(at: point, time: 0.16, interval: 0.5) == 2)
        precondition(clicks.press(at: point, time: 0.8, interval: 0.5) == 1, "Slow presses are separate clicks")
        _ = clicks.release(at: point, time: 0.84, interval: 0.5)
        precondition(clicks.press(at: CGPoint(x: 110, y: 100), time: 0.9, interval: 0.5) == 1, "Distant clicks are separate")
        clicks.movedWhilePressed()
        _ = clicks.release(at: point, time: 0.94, interval: 0.5)
        precondition(clicks.press(at: point, time: 1, interval: 0.5) == 1, "A drag cannot prime double-click")
        _ = clicks.release(at: point, time: 2, interval: 0.5)
        precondition(clicks.press(at: point, time: 2.1, interval: 0.5) == 1, "A long hold resets the sequence")
        _ = clicks.release(at: point, time: 2.15, interval: 0.5)
        clicks.reset()
        precondition(clicks.press(at: point, time: 2.2, interval: 0.5) == 1)
        print("Click tests passed: fast double-click, matching release counts, timeout, distance, drag, long hold, and reset.")
    }
}
