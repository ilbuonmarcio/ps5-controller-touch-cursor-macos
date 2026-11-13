import Foundation
import CoreGraphics

@main struct GestureTests {
    static func main() {
        func pair(center: Float = 0, span: Float = 0.3, y: Float = 0) -> [DualSenseTouch] {
            [DualSenseTouch(x: center - span / 2, y: y, contactID: 1, touching: true),
             DualSenseTouch(x: center + span / 2, y: y, contactID: 2, touching: true)]
        }
        var g = TouchGestures()
        precondition(g.update(touches: pair(), clicked: false, time: 0).suppressCursor)
        precondition(!g.update(touches: [pair()[0]], clicked: false, time: 0.08).rightClick)
        precondition(g.update(touches: [], clicked: false, time: 0.12).rightClick, "A short staggered lift should right click")
        precondition(!g.update(touches: [], clicked: false, time: 0.14).rightClick, "Tap fires once")

        g.reset()
        _ = g.update(touches: pair(), clicked: false, time: 0)
        precondition(!g.update(touches: [], clicked: false, time: 0.4).rightClick, "Long holds/gaps aren't taps")
        g.reset()
        _ = g.update(touches: pair(), clicked: true, time: 0)
        precondition(!g.update(touches: [], clicked: false, time: 0.1).rightClick, "Physical clicks aren't taps")

        g.reset()
        _ = g.update(touches: pair(), clicked: false, time: 0)
        var scrolled = false
        for i in 1...30 {
            let output = g.update(touches: pair(center: Float(i) * 0.003, y: Float(i) * 0.002), clicked: false, time: Double(i) / 120)
            precondition(output.suppressCursor && output.zoomSteps == 0 && !output.rightClick)
            if output.scroll.x > 0 && output.scroll.y > 0 { scrolled = true }
        }
        precondition(scrolled, "Translation must produce smoothed scrolling on both axes")
        precondition(g.update(touches: [pair()[0]], clicked: false, time: 0.26).suppressCursor)
        precondition(!g.update(touches: [], clicked: false, time: 0.28).rightClick, "Scroll release cannot right click")
        precondition(!g.update(touches: [pair()[0]], clicked: false, time: 0.30).suppressCursor, "Lift both fingers restores cursor")

        for direction: Float in [1, -1] {
            g.reset()
            _ = g.update(touches: pair(span: 0.5), clicked: false, time: 0)
            var steps = 0
            var lastStep = -1.0
            for i in 1...90 {
                let time = Double(i) / 120
                let output = g.update(touches: pair(span: 0.5 + direction * Float(i) * 0.003), clicked: false, time: time)
                precondition(output.scroll == .zero && !output.rightClick)
                if output.zoomSteps != 0 {
                    precondition(time - lastStep >= 0.12 - 0.00001, "Zoom shortcut rate must be bounded")
                    lastStep = time
                    steps += output.zoomSteps
                }
            }
            precondition(Double(steps) * Double(direction) > 0, "Pinch direction must match zoom direction")
            precondition(!g.update(touches: [], clicked: false, time: 0.76).rightClick)
        }

        g.reset()
        _ = g.update(touches: pair(), clicked: false, time: 0)
        var replacement = pair()
        replacement[1] = DualSenseTouch(x: 0.2, y: 0, contactID: 3, touching: true)
        precondition(g.update(touches: replacement, clicked: false, time: 0.05).suppressCursor)
        precondition(!g.update(touches: [], clicked: false, time: 0.1).rightClick, "Contact replacement cancels tap")
        g.reset()
        _ = g.update(touches: pair(), clicked: false, time: 0)
        _ = g.update(touches: [pair()[0]], clicked: false, time: 0.05)
        precondition(!g.update(touches: [], clicked: false, time: 0.2).rightClick, "Slow staggered lift isn't a tap")
        func scrollTravel(speed: Double) -> Double {
            var gesture = TouchGestures()
            var total = 0.0
            for i in 0...90 {
                let output = gesture.update(touches: pair(center: Float(min(i, 60)) * 0.003), clicked: false,
                                            time: Double(i) / 120, scrollSpeed: speed)
                total += Double(output.scroll.x)
            }
            return total
        }
        let slow = scrollTravel(speed: 0.25)
        let normal = scrollTravel(speed: 0.5)
        let fast = scrollTravel(speed: 1)
        precondition(slow > 0 && slow < normal && normal < fast)
        precondition(abs(normal * 2 - fast) <= 1 && abs(slow * 4 - fast) <= 2, "Scroll speed must scale accumulated travel without dropping fractional movement")
        print("Gesture tests passed: taps, cancellation, scrolling and speed scaling, cursor suppression, pinch direction, and zoom rate limiting.")
    }
}
