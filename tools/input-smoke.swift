import Foundation

@main struct InputSmoke {
    static func main() {
        let input = DualSenseInput()
        var count = 0
        input.onState = { print($0) }
        input.onReport = { report in
            count += 1
            if count == 1 { print("First decoded report: touching=\(report.touching), clicked=\(report.clicked)") }
        }
        input.start()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 3))
        input.stop()
        print("Decoded \(count) full reports")
        if count == 0 { exit(1) }
    }
}
