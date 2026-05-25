import Foundation
import GRDB

struct GitRepository: Identifiable, Codable, FetchableRecord, PersistableRecord, Hashable {
    var id: String
    var localPath: String
    var name: String
    var currentBranch: String?
    var isDirty: Bool
    var lastCommitMessage: String?
    var lastCommitDate: Date?
    var remoteURL: String?

    init(
        id: String = UUID().uuidString,
        localPath: String,
        name: String,
        currentBranch: String? = nil,
        isDirty: Bool = false,
        lastCommitMessage: String? = nil,
        lastCommitDate: Date? = nil,
        remoteURL: String? = nil
    ) {
        self.id = id
        self.localPath = localPath
        self.name = name
        self.currentBranch = currentBranch
        self.isDirty = isDirty
        self.lastCommitMessage = lastCommitMessage
        self.lastCommitDate = lastCommitDate
        self.remoteURL = remoteURL
    }
}

struct GitCommit: Identifiable {
    var id: String { sha }
    let sha: String
    let message: String
    let author: String
    let date: Date
    let parentSHAs: [String]

    var shortSha: String { String(sha.prefix(7)) }
}

struct GitFileStatus: Identifiable {
    var id: String { "\(path).\(statusCode.rawValue)" }
    let path: String
    let statusCode: GitStatusType
}

enum GitStatusType: String {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case untracked = "?"
    case renamed = "R"

    var label: String {
        switch self {
        case .modified: "Modified"
        case .added: "Added"
        case .deleted: "Deleted"
        case .untracked: "Untracked"
        case .renamed: "Renamed"
        }
    }
}
