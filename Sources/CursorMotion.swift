import Foundation
import CoreGraphics

/// Converts touch positions into smoothed relative movement in screen points.
/// Button transitions discard motion so pressing the pad doesn't drag a target.
struct CursorMotion {
    private var contact: UInt8?
    private var accepted: CGPoint?
    private var filtered: CGPoint?
    private var lastTime: TimeInterval?
    private var remainder = CGPoint.zero
    private var pressed = false
    private var suppressUntil: TimeInterval = 0
    private var dragAnchor: CGPoint?
    private var dragging = false

    mutating func reset() { self = CursorMotion() }

    mutating func update(x: Float, y: Float, touching: Bool, contactID: UInt8,
                         clicked: Bool, time: TimeInterval, sensitivity: Double) -> CGPoint? {
        let point = CGPoint(x: Double(x) * 650 * sensitivity, y: -Double(y) * 365 * sensitivity)
        if clicked != pressed {
            pressed = clicked
            dragging = false
            // Let the finger settle under pressure, and absorb the release wobble.
            suppressUntil = time + (clicked ? 0.12 : 0.06)
            clearTracking()
        }
        guard touching else { clearTracking(); return nil }
        guard time >= suppressUntil else { clearTracking(); return nil }
        guard contact == contactID, let oldAccepted = accepted, let oldFiltered = filtered,
              let oldTime = lastTime, time > oldTime, time - oldTime < 0.25 else {
            begin(point, contactID: contactID, time: time)
            return nil
        }
        guard abs(point.x - oldAccepted.x) < 300 * sensitivity,
              abs(point.y - oldAccepted.y) < 200 * sensitivity else {
            begin(point, contactID: contactID, time: time)
            return nil
        }
        if pressed && !dragging {
            let anchor = dragAnchor ?? point
            // A held click stays still until the user deliberately slides ~9 points.
            guard hypot(point.x - anchor.x, point.y - anchor.y) >= 9 else {
                lastTime = time
                return nil
            }
            dragging = true
            begin(point, contactID: contactID, time: time)
            return nil
        }
        let distance = hypot(point.x - oldAccepted.x, point.y - oldAccepted.y)
        // A small spatial dead zone rejects sensor noise without losing slow travel.
        let radius = 0.65
        let target: CGPoint
        if distance > radius {
            target = CGPoint(x: point.x - (point.x - oldAccepted.x) * radius / distance,
                             y: point.y - (point.y - oldAccepted.y) * radius / distance)
        } else { target = oldAccepted }
        // Time-based filtering gives similar feel at different Bluetooth report rates.
        let alpha = 1 - exp(-(time - oldTime) / 0.025)
        let next = CGPoint(x: oldFiltered.x + (target.x - oldFiltered.x) * alpha,
                           y: oldFiltered.y + (target.y - oldFiltered.y) * alpha)
        accepted = target
        filtered = next
        lastTime = time
        remainder.x += next.x - oldFiltered.x
        remainder.y += next.y - oldFiltered.y
        let movement = CGPoint(x: remainder.x.rounded(), y: remainder.y.rounded())
        remainder.x -= movement.x
        remainder.y -= movement.y
        return movement == .zero ? nil : movement
    }

    private mutating func clearTracking() {
        contact = nil
        accepted = nil
        filtered = nil
        lastTime = nil
        dragAnchor = nil
        remainder = .zero
    }

    private mutating func begin(_ point: CGPoint, contactID: UInt8, time: TimeInterval) {
        contact = contactID
        accepted = point
        filtered = point
        lastTime = time
        dragAnchor = point
        remainder = .zero
    }
}
