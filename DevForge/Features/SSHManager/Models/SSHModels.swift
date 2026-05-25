import Foundation

struct SSHHost: Identifiable, Codable, Hashable {
    var id: String
    var alias: String
    var hostname: String
    var user: String
    var port: Int
    var identityFile: String
    var proxyJump: String
    var forwardAgent: Bool

    init(
        id: String = UUID().uuidString,
        alias: String,
        hostname: String = "",
        user: String = "",
        port: Int = 22,
        identityFile: String = "",
        proxyJump: String = "",
        forwardAgent: Bool = false
    ) {
        self.id = id
        self.alias = alias
        self.hostname = hostname
        self.user = user
        self.port = port
        self.identityFile = identityFile
        self.proxyJump = proxyJump
        self.forwardAgent = forwardAgent
    }
}

struct PortForwardRule: Identifiable {
    let id = UUID()
    let localPort: Int
    let remoteHost: String
    let remotePort: Int
    let viaHost: SSHHost
    var isActive: Bool
}
