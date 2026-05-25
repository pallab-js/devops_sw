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
        let result = try await ShellService.shared.runCommand(
            executable: dockerPath(),
            arguments: ["compose", "-f", url.path, "config", "--services"]
        )
        let serviceNames = result.output
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }

        var services: [ComposeService] = []
        for name in serviceNames {
            _ = try await ShellService.shared.runCommand(
                executable: dockerPath(),
                arguments: ["compose", "-f", url.path, "config", "--format", "json"]
            )
            services.append(ComposeService(
                id: name,
                name: name,
                image: nil,
                ports: [],
                environment: [:]
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
