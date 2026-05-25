import Foundation
import GRDB

struct EnvFile: Identifiable, Codable, FetchableRecord, PersistableRecord, Hashable {
    var id: String
    var name: String
    var projectPath: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        projectPath: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.projectPath = projectPath
        self.createdAt = createdAt
    }
}

struct EnvVariable: Identifiable, Codable, FetchableRecord, PersistableRecord {
    var id: String
    var envFileId: String
    var key: String
    var value: String
    var isSecret: Bool
    var desc: String

    init(
        id: String = UUID().uuidString,
        envFileId: String,
        key: String,
        value: String,
        isSecret: Bool = false,
        desc: String = ""
    ) {
        self.id = id
        self.envFileId = envFileId
        self.key = key
        self.value = value
        self.isSecret = isSecret
        self.desc = desc
    }
}
