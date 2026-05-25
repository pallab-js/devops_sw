import Foundation
import GRDB

enum ProcessStatus: String, Codable, CaseIterable {
    case idle
    case running
    case stopped
    case failed
    case crashed
}

struct ProcessRecord: Identifiable, Codable, FetchableRecord, PersistableRecord, Hashable {
    var id: String
    var name: String
    var command: String
    var workingDirectory: String
    var environmentVariables: [String: String]
    var pid: Int32?
    var status: ProcessStatus
    var createdAt: Date
    var lastStartedAt: Date?

    init(
        id: String = UUID().uuidString,
        name: String,
        command: String,
        workingDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path,
        environmentVariables: [String: String] = [:],
        pid: Int32? = nil,
        status: ProcessStatus = .idle,
        createdAt: Date = Date(),
        lastStartedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.environmentVariables = environmentVariables
        self.pid = pid
        self.status = status
        self.createdAt = createdAt
        self.lastStartedAt = lastStartedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, command, workingDirectory, environmentVariables
        case pid, status, createdAt, lastStartedAt
    }

    mutating func setRunning(pid: Int32) {
        self.pid = pid
        self.status = .running
        self.lastStartedAt = Date()
    }

    mutating func setStopped() {
        self.pid = nil
        self.status = .stopped
    }

    mutating func setFailed() {
        self.pid = nil
        self.status = .failed
    }
}

struct ProcessTemplate: Identifiable, Codable, FetchableRecord, PersistableRecord {
    var id: String
    var name: String
    var command: String
    var workingDirectory: String
    var environmentVariables: [String: String]

    init(
        id: String = UUID().uuidString,
        name: String,
        command: String,
        workingDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path,
        environmentVariables: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.environmentVariables = environmentVariables
    }
}
