import Foundation
import CoreGraphics

struct GestureOutput {
    var suppressCursor = false
    var scroll = CGPoint.zero
    var zoomSteps = 0
    var rightClick = false
    var label = ""
}

/// Gesture ownership lasts until both fingers lift, preventing cursor jumps on exit.
struct TouchGestures {
    private enum Mode { case pending, scroll, zoom }
    private var mode = Mode.pending
    private var initial: [CGPoint] = []
    private var ids: [UInt8] = []
    private var startTime: TimeInterval = 0
    private var lastTime: TimeInterval?
    private var firstTouchTime: TimeInterval?
    private var firstLiftTime: TimeInterval?
    private var tapPossible = false
    private var blocked = false
    private var filteredCenter = CGPoint.zero
    private var filteredSpan = 0.0
    private var scrollRemainder = CGPoint.zero
    private var zoomRemainder = 0.0
    private var lastZoomTime: TimeInterval = -.infinity

    mutating func reset() { self = TouchGestures() }

    mutating func update(touches: [DualSenseTouch], clicked: Bool, time: TimeInterval, scrollSpeed: Double = 0.5) -> GestureOutput {
        let active = touches.filter(\.touching).sorted { $0.contactID < $1.contactID }
        var output = GestureOutput()
        if let lastTime, time - lastTime > 0.25, !initial.isEmpty {
            tapPossible = false
            blocked = true
        }
        lastTime = time
        if active.isEmpty {
            output.suppressCursor = !initial.isEmpty || blocked
            output.rightClick = !initial.isEmpty && !blocked && tapPossible && !clicked && time - startTime <= 0.30 && (firstLiftTime.map { time - $0 <= 0.12 } ?? true)
            reset()
            return output
        }
        if firstTouchTime == nil { firstTouchTime = time }
        if blocked { output.suppressCursor = true; return output }
        if initial.isEmpty {
            guard active.count == 2 else { return output }
            initial = active.map(Self.point)
            ids = active.map(\.contactID)
            startTime = time
            filteredCenter = Self.center(initial)
            filteredSpan = Self.span(initial)
            tapPossible = !clicked && time - (firstTouchTime ?? time) <= 0.18
            output.suppressCursor = true
            output.label = "Two fingers: tap, scroll, or pinch"
            return output
        }
        output.suppressCursor = true
        if clicked { tapPossible = false; blocked = true; return output }
        guard active.count == 2 else {
            if firstLiftTime == nil { firstLiftTime = time }
            return output
        }
        guard firstLiftTime == nil, active.map(\.contactID) == ids else {
            tapPossible = false
            blocked = true
            return output
        }
        let points = active.map(Self.point)
        let center = Self.center(points)
        let span = Self.span(points)
        let originalCenter = Self.center(initial)
        let translation = hypot(center.x - originalCenter.x, center.y - originalCenter.y)
        let separation = abs(span - Self.span(initial))
        if zip(points, initial).contains(where: { hypot($0.x - $1.x, $0.y - $1.y) > 10 }) { tapPossible = false }
        let oldTime = previousSampleTime ?? startTime
        previousSampleTime = time
        let alpha = 1 - exp(-max(0, min(time - oldTime, 0.05)) / 0.035)
        if mode == .pending {
            if separation > 9 && separation > translation * 1.4 && Self.span(initial) > 20 {
                mode = .zoom
            } else if translation > 6 && translation > separation * 0.7 {
                mode = .scroll
            } else { return output }
            tapPossible = false
            // Discard the recognition threshold instead of jumping on activation.
            filteredCenter = center
            filteredSpan = span
        }
        switch mode {
        case .scroll:
            output.label = "Two fingers: scrolling"
            let next = CGPoint(x: filteredCenter.x + (center.x - filteredCenter.x) * alpha,
                               y: filteredCenter.y + (center.y - filteredCenter.y) * alpha)
            scrollRemainder.x += (next.x - filteredCenter.x) * 1.5 * scrollSpeed
            scrollRemainder.y -= (next.y - filteredCenter.y) * 1.5 * scrollSpeed
            output.scroll = CGPoint(x: scrollRemainder.x.rounded(), y: scrollRemainder.y.rounded())
            scrollRemainder.x -= output.scroll.x
            scrollRemainder.y -= output.scroll.y
            filteredCenter = next
        case .zoom:
            output.label = "Two fingers: pinch zoom"
            let next = filteredSpan + (span - filteredSpan) * alpha
            zoomRemainder += log(max(next, 1) / max(filteredSpan, 1))
            filteredSpan = next
            // Rate-limit standard app zoom shortcuts; never leave modifiers held.
            if abs(zoomRemainder) >= 0.14 && time - lastZoomTime >= 0.12 {
                output.zoomSteps = zoomRemainder > 0 ? 1 : -1
                zoomRemainder -= Double(output.zoomSteps) * 0.14
                lastZoomTime = time
            }
        case .pending: break
        }
        return output
    }

    private var previousSampleTime: TimeInterval?
    private static func point(_ touch: DualSenseTouch) -> CGPoint {
        CGPoint(x: Double(touch.x) * 650, y: -Double(touch.y) * 365)
    }
    private static func center(_ points: [CGPoint]) -> CGPoint {
        CGPoint(x: (points[0].x + points[1].x) / 2, y: (points[0].y + points[1].y) / 2)
    }
    private static func span(_ points: [CGPoint]) -> Double {
        Double(hypot(points[0].x - points[1].x, points[0].y - points[1].y))
    }
}
