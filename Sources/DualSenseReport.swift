import Foundation

struct DualSenseReport {
    let x: Float
    let y: Float
    let contactID: UInt8
    let touching: Bool
    let clicked: Bool

    // DualSense wire format: USB 0x01 has a one-byte header, Bluetooth
    // 0x31 has a two-byte header. Short Bluetooth 0x01 has no touch data.
    init?(_ bytes: [UInt8]) {
        let offset: Int
        if bytes.count == 78 && bytes.first == 0x31 { offset = 2 }
        else if bytes.count == 64 && bytes.first == 0x01 { offset = 1 }
        else { return nil }
        let point = offset + 32
        let rawX = Int(bytes[point + 1]) | (Int(bytes[point + 2] & 0x0f) << 8)
        let rawY = Int(bytes[point + 2] >> 4) | (Int(bytes[point + 3]) << 4)
        touching = bytes[point] & 0x80 == 0 && rawX < 1920 && rawY < 1080
        contactID = bytes[point] & 0x7f
        x = Float(rawX) / 1919 * 2 - 1
        y = 1 - Float(rawY) / 1079 * 2
        clicked = bytes[offset + 9] & 0x02 != 0
    }
}
