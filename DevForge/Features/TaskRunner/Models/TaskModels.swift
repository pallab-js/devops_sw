import Foundation
import GRDB

struct DiscoveredTask: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let command: String
    let sourceFile: String
    let sourceType: SourceType

    enum SourceType: String {
        case makefile = "Makefile"
        case packageJSON = "package.json"
        case justfile = "Justfile"
    }
}

struct TaskOutputLine: Identifiable, Sendable {
    let id = UUID()
    let content: String
    let isError: Bool
    let timestamp: Date
}

struct TaskRun: Identifiable, Codable, FetchableRecord, PersistableRecord {
    var id: String
    var taskName: String
    var command: String
    var workingDirectory: String
    var startTime: Date
    var endTime: Date?
    var exitCode: Int32?

    init(
        id: String = UUID().uuidString,
        taskName: String,
        command: String,
        workingDirectory: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        exitCode: Int32? = nil
    ) {
        self.id = id
        self.taskName = taskName
        self.command = command
        self.workingDirectory = workingDirectory
        self.startTime = startTime
        self.endTime = endTime
        self.exitCode = exitCode
    }

    var duration: TimeInterval? {
        guard let endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
}
