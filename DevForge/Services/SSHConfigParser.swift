import Foundation

actor SSHConfigParser {
    static let shared = SSHConfigParser()

    private var configPath: String {
        NSHomeDirectory() + "/.ssh/config"
    }

    func loadHosts() throws -> [SSHHost] {
        guard FileManager.default.fileExists(atPath: configPath) else {
            return []
        }
        let content = try String(contentsOfFile: configPath, encoding: .utf8)
        return parseConfig(content)
    }

    func saveHosts(_ hosts: [SSHHost]) throws {
        let content = generateConfig(hosts)
        let tempPath = configPath + ".tmp"
        try content.write(toFile: tempPath, atomically: true, encoding: .utf8)
        _ = try FileManager.default.replaceItemAt(
            URL(fileURLWithPath: configPath),
            withItemAt: URL(fileURLWithPath: tempPath)
        )
    }

    func ensureConfigExists() throws {
        guard !FileManager.default.fileExists(atPath: configPath) else { return }
        let dir = (configPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: configPath, contents: nil)
    }

    private func parseConfig(_ content: String) -> [SSHHost] {
        var hosts: [SSHHost] = []
        var currentHost: (alias: String, lines: [String])?

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmed
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if trimmed.lowercased().hasPrefix("host ") {
                if let current = currentHost {
                    if let host = parseHostBlock(alias: current.alias, lines: current.lines) {
                        hosts.append(host)
                    }
                }
                let alias = String(trimmed.dropFirst(5)).trimmed
                if alias != "*" {
                    currentHost = (alias, [])
                } else {
                    currentHost = nil
                }
            } else if currentHost != nil {
                currentHost?.lines.append(trimmed)
            }
        }
        if let current = currentHost {
            if let host = parseHostBlock(alias: current.alias, lines: current.lines) {
                hosts.append(host)
            }
        }
        return hosts
    }

    private func parseHostBlock(alias: String, lines: [String]) -> SSHHost? {
        var hostname = ""
        var user = ""
        var port = 22
        var identityFile = ""
        var proxyJump = ""
        var forwardAgent = false

        for line in lines {
            let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard parts.count == 2 else { continue }
            let key = parts[0].lowercased()
            let value = String(parts[1]).trimmed

            switch key {
            case "hostname": hostname = value
            case "user": user = value
            case "port": port = Int(value) ?? 22
            case "identityfile": identityFile = value
            case "proxyjump": proxyJump = value
            case "forwardagent": forwardAgent = value.lowercased() == "yes"
            default: break
            }
        }
        guard !hostname.isEmpty else { return nil }
        return SSHHost(
            alias: alias,
            hostname: hostname,
            user: user,
            port: port,
            identityFile: identityFile,
            proxyJump: proxyJump,
            forwardAgent: forwardAgent
        )
    }

    private func generateConfig(_ hosts: [SSHHost]) -> String {
        var lines: [String] = []
        lines.append("# SSH Config managed by DevForge")
        lines.append("")
        for host in hosts {
            lines.append("Host \(host.alias)")
            lines.append("    HostName \(host.hostname)")
            if !host.user.isEmpty { lines.append("    User \(host.user)") }
            if host.port != 22 { lines.append("    Port \(host.port)") }
            if !host.identityFile.isEmpty { lines.append("    IdentityFile \(host.identityFile)") }
            if !host.proxyJump.isEmpty { lines.append("    ProxyJump \(host.proxyJump)") }
            if host.forwardAgent { lines.append("    ForwardAgent yes") }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
