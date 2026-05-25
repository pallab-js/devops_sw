import Foundation

struct DockerContainer: Codable, Identifiable {
    let id: String
    let names: [String]
    let image: String
    let status: String
    let state: String
    let ports: [DockerPort]
    let created: Int64

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case names = "Names"
        case image = "Image"
        case status = "Status"
        case state = "State"
        case ports = "Ports"
        case created = "Created"
    }

    var displayName: String {
        names.first?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? id.prefix(12).description
    }

    var shortId: String { String(id.prefix(12)) }
}

struct DockerPort: Codable {
    let privatePort: Int?
    let publicPort: Int?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case privatePort = "PrivatePort"
        case publicPort = "PublicPort"
        case type = "Type"
    }

    var display: String {
        if let publicPort, let privatePort {
            return "\(publicPort)->\(privatePort)/\(type ?? "tcp")"
        }
        if let privatePort {
            return "\(privatePort)/\(type ?? "tcp")"
        }
        return ""
    }
}

struct DockerImage: Codable, Identifiable {
    let id: String
    let repoTags: [String]?
    let size: Int64
    let created: Int64

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case repoTags = "RepoTags"
        case size = "Size"
        case created = "Created"
    }

    var shortId: String { String(id.replacingOccurrences(of: "sha256:", with: "").prefix(12)) }

    var displayTag: String {
        repoTags?.first ?? "<none>:<none>"
    }

    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct DockerContainerDetail: Codable {
    let id: String
    let name: String
    let state: DockerState
    let config: DockerConfig?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case state = "State"
        case config = "Config"
    }
}

struct DockerState: Codable {
    let status: String?
    let running: Bool?
    let startedAt: String?
    let finishedAt: String?

    enum CodingKeys: String, CodingKey {
        case status = "Status"
        case running = "Running"
        case startedAt = "StartedAt"
        case finishedAt = "FinishedAt"
    }
}

struct DockerConfig: Codable {
    let image: String?
    let env: [String]?

    enum CodingKeys: String, CodingKey {
        case image = "Image"
        case env = "Env"
    }
}
