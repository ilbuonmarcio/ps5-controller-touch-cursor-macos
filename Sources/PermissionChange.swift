/// Observe Accessibility trust, independently of cached mouse-posting access.
/// Wait for two granted samples after observing a denial, avoiding relaunches
/// on startup or while a privacy setting is briefly toggled.
struct PermissionChange {
    private var sawDenial = false
    private var grantedSamples = 0

    mutating func update(granted: Bool) -> Bool {
        guard granted else {
            sawDenial = true
            grantedSamples = 0
            return false
        }
        guard sawDenial else { return false }
        grantedSamples += 1
        guard grantedSamples >= 2 else { return false }
        sawDenial = false
        grantedSamples = 0
        return true
    }
}
