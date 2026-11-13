@main struct PermissionTests {
    static func main() {
        var watcher = PermissionChange()
        precondition(!watcher.update(granted: true), "Already authorized startup must not relaunch")
        precondition(!watcher.update(granted: true))
        precondition(!watcher.update(granted: false))
        precondition(!watcher.update(granted: true), "One sample is not enough")
        precondition(!watcher.update(granted: false), "Revocation cancels pending grant")
        precondition(!watcher.update(granted: true))
        precondition(watcher.update(granted: true), "Stable grant should relaunch once")
        for _ in 0..<20 { precondition(!watcher.update(granted: true), "No restart loop") }
        var newProcess = PermissionChange()
        precondition(!newProcess.update(granted: true), "The new instance must not restart again")
        precondition(!watcher.update(granted: false))
        precondition(!watcher.update(granted: true))
        precondition(watcher.update(granted: true), "Later revocation and regrant must be handled")
        // Reproduce the observed state: AX trust updates before posting access.
        var stalePosting = PermissionChange()
        _ = stalePosting.update(granted: false)
        let accessibility = true
        let posting = false
        precondition(!stalePosting.update(granted: accessibility))
        precondition(stalePosting.update(granted: accessibility) && !posting,
                     "Restart must trigger even while mouse-event permission remains stale")
        print("Permission tests passed: startup, stable grant, transient changes, one-shot restart, and regrant.")
    }
}
