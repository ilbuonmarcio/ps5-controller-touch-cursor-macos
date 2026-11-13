import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: NSStatusItem!
    private let menu = NSMenu()
    private let connection = NSMenuItem(title: "Searching for DualSense…", action: nil, keyEquivalent: "")
    private let activity = NSMenuItem(title: "Touchpad: waiting for input", action: nil, keyEquivalent: "")
    private let cursorStatus = NSMenuItem(title: "Cursor: checking permission…", action: nil, keyEquivalent: "")
    private var enabledItem: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private let input = DualSenseInput()
    private var motion = CursorMotion()
    private var gestures = TouchGestures()
    private var timer: Timer?
    private var mouseDown = false
    private var clicks = ClickSequence()
    private var enabled = !CommandLine.arguments.contains("--cursor-disabled")
    private var permissionChange = PermissionChange()
    private var relaunching = false
    private var lastPermissionState: String?
    private var sensitivity = UserDefaults.standard.object(forKey: "sensitivity") as? Double ?? 1.0
    private var scrollSpeed = UserDefaults.standard.object(forKey: "scrollSpeed") as? Double ?? 0.5

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "gamecontroller", accessibilityDescription: "DualSense Cursor")
        status.menu = menu
        menu.addItem(connection)
        menu.addItem(activity)
        menu.addItem(cursorStatus)
        menu.addItem(.separator())
        enabledItem = add("Enable cursor", #selector(toggleEnabled))
        enabledItem.state = enabled ? .on : .off
        let sensitivityMenu = NSMenu()
        for (label, value) in [("Slow", 0.5), ("Normal", 1.0), ("Fast", 2.0)] {
            let item = NSMenuItem(title: label, action: #selector(changeSensitivity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = sensitivity == value ? .on : .off
            sensitivityMenu.addItem(item)
        }
        let speed = NSMenuItem(title: "Cursor speed", action: nil, keyEquivalent: "")
        speed.submenu = sensitivityMenu
        menu.addItem(speed)
        let scrollMenu = NSMenu()
        for (label, value) in [("Slow", 0.25), ("Normal", 0.5), ("Fast", 1.0)] {
            let item = NSMenuItem(title: label, action: #selector(changeScrollSpeed(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = scrollSpeed == value ? .on : .off
            scrollMenu.addItem(item)
        }
        let scrolling = NSMenuItem(title: "Scroll speed", action: nil, keyEquivalent: "")
        scrolling.submenu = scrollMenu
        menu.addItem(scrolling)
        permissionItem = add("Grant Accessibility permission…", #selector(requestPermission))
        menu.addItem(.separator())
        add("Quit DualSense Cursor", #selector(quit))
        input.onState = { [weak self] state in
            self?.connection.title = state
            self?.resetPointer()
            self?.activity.title = "Touchpad: waiting for input"
        }
        input.onReport = { [weak self] report in self?.receive(report) }
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.updatePermissionStatus()
        }
        RunLoop.main.add(timer!, forMode: .common)
        updatePermissionStatus()
        input.start()
    }

    private var canPostMouseEvents: Bool { AXIsProcessTrusted() && CGPreflightPostEventAccess() }

    private func updatePermissionStatus() {
        let accessibility = AXIsProcessTrusted()
        let posting = CGPreflightPostEventAccess()
        permissionItem.title = accessibility && posting ? "Accessibility granted ✓" : "Grant Accessibility permission…"
        cursorStatus.title = !enabled ? "Cursor: disabled" : accessibility && posting ? "Cursor: ready" : "Cursor: blocked by Accessibility"
        if !accessibility || !posting { resetPointer() }
        let state = "Accessibility trusted: \(accessibility)\nMouse event posting allowed: \(posting)\nCursor enabled: \(enabled)\nProcess: \(ProcessInfo.processInfo.processIdentifier)\nApp: \(Bundle.main.bundlePath)\n"
        if state != lastPermissionState {
            lastPermissionState = state
            let url = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("cursor-status.txt")
            try? state.write(to: url, atomically: true, encoding: .utf8)
        }
        // Mouse-posting access can remain stale until this process restarts.
        // Observe the Accessibility grant itself; waiting for posting deadlocks
        // the restart precisely when it is needed to refresh that permission.
        if permissionChange.update(granted: accessibility) { relaunchAfterPermissionChange() }
    }

    private func relaunchAfterPermissionChange() {
        guard !relaunching else { return }
        relaunching = true
        resetPointer()
        cursorStatus.title = "Cursor: restarting after permission change…"
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = false
        configuration.arguments = enabled ? [] : ["--cursor-disabled"]
        // Ask Launch Services to start a fresh instance before exiting this one.
        // If launching fails, leave the current instance running and usable.
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] application, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if application != nil && error == nil {
                    NSApp.terminate(nil)
                } else {
                    self.relaunching = false
                    self.cursorStatus.title = "Cursor: automatic restart failed; quit and reopen"
                }
            }
        }
    }

    @discardableResult private func add(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    private func receive(_ report: DualSenseReport) {
        activity.title = report.touching ? String(format: "Touchpad: %.2f, %.2f", report.x, report.y) : "Touchpad: finger lifted · receiving input"
        guard enabled, canPostMouseEvents else { resetPointer(); return }
        let gesture = gestures.update(touches: report.touches, clicked: report.clicked,
                                      time: ProcessInfo.processInfo.systemUptime, scrollSpeed: scrollSpeed)
        if gesture.suppressCursor {
            motion.reset()
            click(false)
            clicks.reset()
            if !gesture.label.isEmpty { activity.title = gesture.label }
            if gesture.rightClick { postRightClick() }
            if gesture.scroll != .zero { postScroll(gesture.scroll) }
            if gesture.zoomSteps != 0 { postZoom(gesture.zoomSteps) }
            return
        }
        click(report.clicked)
        guard let delta = motion.update(x: report.x, y: report.y, touching: report.touching,
                                        contactID: report.contactID, clicked: report.clicked,
                                        time: ProcessInfo.processInfo.systemUptime, sensitivity: sensitivity) else { return }
        guard let current = CGEvent(source: nil)?.location else { return }
        let mainTop = NSScreen.screens.first?.frame.maxY ?? 0
        let desired = CGPoint(x: current.x + delta.x, y: current.y + delta.y)
        // Clamp to an actual display, including layouts with gaps between screens.
        let frames = NSScreen.screens.map { CGRect(x: $0.frame.minX, y: mainTop - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height) }
        let point = frames.map { frame in
            CGPoint(x: min(max(desired.x, frame.minX), frame.maxX - 1), y: min(max(desired.y, frame.minY), frame.maxY - 1))
        }.min { hypot($0.x - desired.x, $0.y - desired.y) < hypot($1.x - desired.x, $1.y - desired.y) } ?? current
        if mouseDown { clicks.movedWhilePressed() }
        let event = CGEvent(mouseEventSource: nil, mouseType: mouseDown ? .leftMouseDragged : .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        if mouseDown { event?.setIntegerValueField(.mouseEventClickState, value: Int64(clicks.count)) }
        event?.post(tap: .cghidEventTap)
    }

    private func click(_ pressed: Bool) {
        guard enabled, canPostMouseEvents else { resetPointer(); return }
        guard pressed != mouseDown else { return }
        mouseDown = pressed
        postButton(pressed)
    }

    private func postButton(_ pressed: Bool) {
        guard let point = CGEvent(source: nil)?.location else { return }
        let time = ProcessInfo.processInfo.systemUptime
        let count = pressed ? clicks.press(at: point, time: time, interval: NSEvent.doubleClickInterval)
                            : clicks.release(at: point, time: time, interval: NSEvent.doubleClickInterval)
        let event = CGEvent(mouseEventSource: nil, mouseType: pressed ? .leftMouseDown : .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        event?.setIntegerValueField(.mouseEventClickState, value: Int64(count))
        event?.post(tap: .cghidEventTap)
    }

    private func postRightClick() {
        clicks.reset()
        guard let point = CGEvent(source: nil)?.location else { return }
        for type in [CGEventType.rightMouseDown, .rightMouseUp] {
            let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .right)
            event?.setIntegerValueField(.mouseEventClickState, value: 1)
            event?.post(tap: .cghidEventTap)
        }
    }

    private func postScroll(_ delta: CGPoint) {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                                  wheel1: Int32(delta.y), wheel2: Int32(delta.x), wheel3: 0) else { return }
        event.flags = []
        if let location = CGEvent(source: nil)?.location { event.location = location }
        event.post(tap: .cghidEventTap)
    }

    private func postZoom(_ direction: Int) {
        // ANSI '=' and '-' are the standard Command zoom shortcuts.
        let key: CGKeyCode = direction > 0 ? 24 : 27
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }

    private func resetPointer() {
        if mouseDown { postButton(false) }
        mouseDown = false
        clicks.reset()
        motion.reset()
        gestures.reset()
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        enabledItem.state = enabled ? .on : .off
        resetPointer()
        updatePermissionStatus()
    }

    @objc private func changeSensitivity(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        sensitivity = value
        UserDefaults.standard.set(value, forKey: "sensitivity")
        sender.menu?.items.forEach { $0.state = $0 === sender ? .on : .off }
        motion.reset()
        gestures.reset()
    }

    @objc private func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        _ = CGRequestPostEventAccess()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func changeScrollSpeed(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        scrollSpeed = value
        UserDefaults.standard.set(value, forKey: "scrollSpeed")
        sender.menu?.items.forEach { $0.state = $0 === sender ? .on : .off }
        resetPointer()
    }

    @objc private func quit() { resetPointer(); NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { resetPointer(); input.stop() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
