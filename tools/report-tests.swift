import Foundation

@main struct ReportTests {
    static func main() {
        for (id, size, offset) in [(UInt8(0x31), 78, 2), (UInt8(0x01), 64, 1)] {
            var bytes = [UInt8](repeating: 0, count: size)
            bytes[0] = id
            bytes[offset + 36] = 0x80 // Second touch is inactive.
            let point = offset + 32
            // Contact 5 at x=960, y=540, with the touchpad pressed.
            bytes[point] = 5
            bytes[point + 1] = 0xc0
            bytes[point + 2] = 0xc3
            bytes[point + 3] = 0x21
            bytes[offset + 9] = 2
            let report = DualSenseReport(bytes)!
            precondition(report.touching && report.clicked && report.contactID == 5)
            precondition(abs(report.x) < 0.002 && abs(report.y) < 0.002)
            bytes[point] |= 0x80
            precondition(!DualSenseReport(bytes)!.touching)
            // The second slot must remain usable when the first finger lifts.
            bytes[offset + 36] = 9
            bytes[offset + 37] = 0xc0
            bytes[offset + 38] = 0xc3
            bytes[offset + 39] = 0x21
            precondition(DualSenseReport(bytes)!.activeTouches.count == 1)
            precondition(DualSenseReport(bytes)!.contactID == 9)
            bytes[offset + 36] = 0x80
            bytes[point] = 6
            bytes[point + 1] = 0xff
            bytes[point + 2] = 0xff
            bytes[point + 3] = 0xff
            precondition(!DualSenseReport(bytes)!.touching)
        }
        precondition(DualSenseReport([]) == nil)
        precondition(DualSenseReport([1, 127, 127, 127, 127, 8, 0, 0, 0, 0]) == nil)
        print("Report tests passed: Bluetooth, USB, center contact, release, invalid coordinates, short reports.")
    }
}
