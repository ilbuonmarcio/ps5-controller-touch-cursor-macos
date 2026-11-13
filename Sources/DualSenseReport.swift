import Foundation

struct DualSenseTouch {
    let x: Float
    let y: Float
    let contactID: UInt8
    let touching: Bool
}

struct DualSenseReport {
    let touches: [DualSenseTouch]
    let clicked: Bool
    var activeTouches: [DualSenseTouch] { touches.filter(\.touching).sorted { $0.contactID < $1.contactID } }
    private var primary: DualSenseTouch { activeTouches.first ?? touches[0] }
    var x: Float { primary.x }
    var y: Float { primary.y }
    var contactID: UInt8 { primary.contactID }
    var touching: Bool { !activeTouches.isEmpty }

    // DualSense wire format: USB 0x01 has a one-byte header, Bluetooth
    // 0x31 has a two-byte header. Short Bluetooth 0x01 has no touch data.
    init?(_ bytes: [UInt8]) {
        let offset: Int
        if bytes.count == 78 && bytes.first == 0x31 { offset = 2 }
        else if bytes.count == 64 && bytes.first == 0x01 { offset = 1 }
        else { return nil }
        touches = (0..<2).map { index in
            let point = offset + 32 + index * 4
            let rawX = Int(bytes[point + 1]) | (Int(bytes[point + 2] & 0x0f) << 8)
            let rawY = Int(bytes[point + 2] >> 4) | (Int(bytes[point + 3]) << 4)
            return DualSenseTouch(x: Float(rawX) / 1919 * 2 - 1,
                                  y: 1 - Float(rawY) / 1079 * 2,
                                  contactID: bytes[point] & 0x7f,
                                  touching: bytes[point] & 0x80 == 0 && rawX < 1920 && rawY < 1080)
        }
        clicked = bytes[offset + 9] & 0x02 != 0
    }
}
