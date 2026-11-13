import Foundation
import GameController
import IOKit.hid

GCController.shouldMonitorBackgroundEvents = true
let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x054c, kIOHIDProductIDKey: 0x0ce6] as CFDictionary)
var reportCount = 0
IOHIDManagerRegisterInputReportCallback(manager, { _, result, _, _, reportID, report, length in
    reportCount += 1
    if reportCount <= 3 || reportCount % 250 == 0 {
        print("HID", result, "ID", reportID, "length", length, "bytes", (0..<min(length, 43)).map { String(format: "%02x", report[$0]) }.joined(separator: " "))
    }
}, nil)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
print("HID open:", IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)))
if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
    for device in devices {
        var data = [UInt8](repeating: 0, count: 64)
        data[0] = 0x20
        var length = data.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 0x20, &data, &length)
        print("Firmware feature request:", result, "length:", length)
    }
}
let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    for controller in GCController.controllers() {
        if let pad = controller.extendedGamepad as? GCDualSenseGamepad {
            print("GC", controller.vendorName ?? "?", "touch", pad.touchpadPrimary.xAxis.value, pad.touchpadPrimary.yAxis.value, "secondary", pad.touchpadSecondary.xAxis.value, pad.touchpadSecondary.yAxis.value, "stick", pad.leftThumbstick.xAxis.value, pad.leftThumbstick.yAxis.value, "last", pad.lastEventTimestamp, "reports", reportCount)
        }
    }
}
RunLoop.main.run(until: Date(timeIntervalSinceNow: 8))
IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
