import Foundation
import CoreGraphics

struct ClickSequence {
    private var previous: (time: TimeInterval, point: CGPoint, count: Int)?
    private var down: (time: TimeInterval, point: CGPoint)?
    private(set) var count = 1

    mutating func press(at point: CGPoint, time: TimeInterval, interval: TimeInterval) -> Int {
        if let previous, time >= previous.time, time - previous.time <= interval,
           hypot(point.x - previous.point.x, point.y - previous.point.y) <= 4 {
            count = previous.count + 1
        } else { count = 1 }
        previous = nil
        down = (time, point)
        return count
    }

    mutating func release(at point: CGPoint, time: TimeInterval, interval: TimeInterval) -> Int {
        if let down, time >= down.time, time - down.time <= interval,
           hypot(point.x - down.point.x, point.y - down.point.y) <= 4 {
            previous = (down.time, down.point, count)
        } else { previous = nil }
        down = nil
        return count
    }

    mutating func movedWhilePressed() {
        // A drag must never prime the next press as a double-click.
        down = nil
        previous = nil
    }

    mutating func reset() { self = ClickSequence() }
}
