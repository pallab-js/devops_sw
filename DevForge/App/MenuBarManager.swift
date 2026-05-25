import SwiftUI

struct MenuBarExtraView: View {
    @State private var runningCount = 0
    @State private var dockerStatus = "unknown"

    var body: some View {
        HStack {
            Image(systemName: "terminal.fill")
            Text("\(runningCount)")
        }
        .task {
            for await _ in AsyncStream<Date>.never {
                runningCount = await ProcessService.shared.runningCount()
            }
        }
    }
}

final class SendableTimer: @unchecked Sendable {
    let timer: Timer
    init(_ timer: Timer) { self.timer = timer }
}

extension AsyncStream where Element == Date {
    static var never: AsyncStream<Date> {
        AsyncStream { continuation in
            let timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                continuation.yield(Date())
            }
            let sendableTimer = SendableTimer(timer)
            continuation.onTermination = { _ in
                sendableTimer.timer.invalidate()
            }
        }
    }
}
