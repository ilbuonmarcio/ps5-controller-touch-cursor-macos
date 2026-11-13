import Foundation
import IOKit.hid

final class DualSenseInput {
    var onState: ((String) -> Void)?
    var onReport: ((DualSenseReport) -> Void)?
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var device: IOHIDDevice?

    func start() {
        // Match only the standard Sony DualSense. Never seize the device.
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x054c, kIOHIDProductIDKey: 0x0ce6] as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<DualSenseInput>.fromOpaque(context).takeUnretainedValue().connected(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            let input = Unmanaged<DualSenseInput>.fromOpaque(context).takeUnretainedValue()
            if let current = input.device, CFEqual(current, device) {
                input.device = nil
                input.onState?("DualSense disconnected")
            }
        }, context)
        IOHIDManagerRegisterInputReportCallback(manager, { context, result, sender, _, _, bytes, length in
            guard result == kIOReturnSuccess, let context, let sender else { return }
            let input = Unmanaged<DualSenseInput>.fromOpaque(context).takeUnretainedValue()
            guard let current = input.device,
                  CFEqual(current, Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()),
                  let report = DualSenseReport(Array(UnsafeBufferPointer(start: bytes, count: length))) else { return }
            input.onReport?(report)
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess { onState?("Controller access failed (\(result))") }
        else { onState?("Searching for DualSense…") }
    }

    private func connected(_ device: IOHIDDevice) {
        guard self.device == nil else { return }
        self.device = device
        // A firmware feature read enables full reports on Bluetooth, without
        // changing lights, rumble, or trigger effects. USB already uses full reports.
        var data = [UInt8](repeating: 0, count: 64)
        data[0] = 0x20
        var length = data.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 0x20, &data, &length)
        onState?(result == kIOReturnSuccess ? "DualSense connected · full input" : "DualSense connected · setup failed (\(result))")
    }

    func stop() {
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        device = nil
    }
}
