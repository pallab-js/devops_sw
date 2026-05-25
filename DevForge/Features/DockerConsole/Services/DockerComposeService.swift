import Foundation

actor DockerComposeService {
    static let shared = DockerComposeService()

    private func dockerPath() -> String {
        let paths = ["/usr/local/bin/docker", "/opt/homebrew/bin/docker", "/usr/bin/docker"]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return "/usr/local/bin/docker"
    }

    func findComposeFiles(in directory: URL) -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return [] }
        return items.filter { $0.lastPathComponent == "docker-compose.yml" || $0.lastPathComponent == "docker-compose.yaml" || $0.lastPathComponent == "compose.yml" || $0.lastPathComponent == "compose.yaml" }
    }

    struct ComposeService: Identifiable {
        let id: String
        let name: String
        let image: String?
        let ports: [String]
        let environment: [String: String]
    }

    func parseComposeFile(url: URL) async throws -> [ComposeService] {
        let data = try Data(contentsOf: url)
        guard let yaml = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return try parseLineByLine(url: url)
        }
        return []
    }

    private func parseLineByLine(url: URL) throws -> [ComposeService] {
        let content = try String(contentsOf: url, encoding: .utf8)
        var services: [ComposeService] = []
        var currentService: String?
        var currentImage: String?
        var currentPorts: [String] = []
        var currentEnv: [String: String] = [:]

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmed
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if trimmed.hasPrefix("services:") {
                continue
            }

            if trimmed.hasPrefix("  ") && !trimmed.hasPrefix("    ") {
                if let name = currentService, !name.isEmpty {
                    let id = UUID().uuidString
                    services.append(ComposeService(
                        id: id, name: name,
                        image: currentImage,
                        ports: currentPorts,
                        environment: currentEnv
                    ))
                }
                let namePart = trimmed.trimmed
                if namePart.hasSuffix(":") {
                    currentService = String(namePart.dropLast()).trimmed
                    currentImage = nil
                    currentPorts = []
                    currentEnv = [:]
                }
                continue
            }

            if trimmed.hasPrefix("image:") {
                currentImage = String(trimmed.dropFirst(6)).trimmed
            } else if trimmed.hasPrefix("ports:") {
                // multi-line ports follow
            } else if trimmed.hasPrefix("- ") && currentPorts.isEmpty == false {
                currentPorts.append(String(trimmed.dropFirst(2)).trimmed)
            } else if trimmed.hasPrefix("environment:") {
                // env block follows
            } else if trimmed.contains(": ") && !trimmed.hasPrefix(" ") {
                let parts = trimmed.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmed
                    let val = String(parts[1]).trimmed
                    currentEnv[key] = val
                }
            }
        }

        if let name = currentService, !name.isEmpty {
            let id = UUID().uuidString
            services.append(ComposeService(
                id: id, name: name,
                image: currentImage,
                ports: currentPorts,
                environment: currentEnv
            ))
        }
        return services
    }

    func runUp(composeFileURL: URL, service: String? = nil) async throws -> String {
        var args = ["compose", "-f", composeFileURL.path, "up", "-d"]
        if let service { args.append(service) }
        let result = try await ShellService.shared.runCommand(
            executable: dockerPath(),
            arguments: args
        )
        return result.output
    }

    func runDown(composeFileURL: URL) async throws -> String {
        let result = try await ShellService.shared.runCommand(
            executable: dockerPath(),
            arguments: ["compose", "-f", composeFileURL.path, "down"]
        )
        return result.output
    }

    func runPS(composeFileURL: URL) async throws -> String {
        let result = try await ShellService.shared.runCommand(
            executable: dockerPath(),
            arguments: ["compose", "-f", composeFileURL.path, "ps"]
        )
        return result.output
    }
}
