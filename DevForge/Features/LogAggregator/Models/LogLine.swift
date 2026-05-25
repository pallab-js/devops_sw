import Foundation

struct LogLine: Identifiable, Sendable, Equatable {
    let id = UUID()
    let content: String
    let timestamp: Date
    let isError: Bool
    let source: String
    let lineNumber: Int

    init(
        content: String,
        timestamp: Date = Date(),
        isError: Bool = false,
        source: String = "",
        lineNumber: Int = 0
    ) {
        self.content = content
        self.timestamp = timestamp
        self.isError = isError
        self.source = source
        self.lineNumber = lineNumber
    }
}
