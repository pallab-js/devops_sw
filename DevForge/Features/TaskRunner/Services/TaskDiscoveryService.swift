import Foundation

actor TaskDiscoveryService {
    static let shared = TaskDiscoveryService()

    func discoverTasks(in directory: URL) async throws -> [DiscoveredTask] {
        var tasks: [DiscoveredTask] = []

        let makefile = directory.appendingPathComponent("Makefile")
        if FileManager.default.fileExists(atPath: makefile.path) {
            tasks.append(contentsOf: try parseMakefile(makefile, directory: directory))
        }

        let packageJSON = directory.appendingPathComponent("package.json")
        if FileManager.default.fileExists(atPath: packageJSON.path) {
            tasks.append(contentsOf: try parsePackageJSON(packageJSON, directory: directory))
        }

        let justfile = directory.appendingPathComponent("Justfile")
        if FileManager.default.fileExists(atPath: justfile.path) {
            tasks.append(contentsOf: try parseJustfile(justfile, directory: directory))
        }

        return tasks
    }

    private func parseMakefile(_ url: URL, directory: URL) throws -> [DiscoveredTask] {
        let content = try String(contentsOf: url, encoding: .utf8)
        var tasks: [DiscoveredTask] = []

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmed
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("\t") else { continue }
            let regex = try NSRegularExpression(pattern: "^[a-zA-Z_-][a-zA-Z0-9_-]*:")
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if regex.firstMatch(in: trimmed, range: range) != nil {
                let name = trimmed.replacingOccurrences(of: ":", with: "").trimmed
                let command = "make \(name)"
                tasks.append(DiscoveredTask(
                    name: name,
                    command: command,
                    sourceFile: "Makefile",
                    sourceType: .makefile
                ))
            }
        }
        return tasks
    }

    private func parsePackageJSON(_ url: URL, directory: URL) throws -> [DiscoveredTask] {
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = json["scripts"] as? [String: String] else {
            return []
        }
        return scripts.map { name, command in
            DiscoveredTask(
                name: name,
                command: command,
                sourceFile: "package.json",
                sourceType: .packageJSON
            )
        }
    }

    private func parseJustfile(_ url: URL, directory: URL) throws -> [DiscoveredTask] {
        let content = try String(contentsOf: url, encoding: .utf8)
        var tasks: [DiscoveredTask] = []

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmed
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let regex = try NSRegularExpression(pattern: "^[a-zA-Z_-][a-zA-Z0-9_-]*:")
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if regex.firstMatch(in: trimmed, range: range) != nil {
                let name = trimmed.replacingOccurrences(of: ":", with: "").trimmed
                tasks.append(DiscoveredTask(
                    name: name,
                    command: "just \(name)",
                    sourceFile: "Justfile",
                    sourceType: .justfile
                ))
            }
        }
        return tasks
    }
}
