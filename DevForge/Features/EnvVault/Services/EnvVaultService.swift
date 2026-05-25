import Foundation
import GRDB

actor EnvVaultService {
    static let shared = EnvVaultService()
    private let keychain = KeychainService.shared

    private init() {}

    func loadEnvFiles() async throws -> [EnvFile] {
        try await AppDatabase.shared.read { db in
            try EnvFile.order(Column("createdAt").desc).fetchAll(db)
        }
    }

    func loadVariables(for envFileId: String) async throws -> [EnvVariable] {
        try await AppDatabase.shared.read { db in
            try EnvVariable
                .filter(Column("envFileId") == envFileId)
                .fetchAll(db)
        }
    }

    func createEnvFile(name: String, projectPath: String) async throws -> EnvFile {
        let file = EnvFile(name: name, projectPath: projectPath)
        try await AppDatabase.shared.write { db in
            try file.insert(db)
        }
        return file
    }

    func deleteEnvFile(_ file: EnvFile) async throws {
        let variables = try await loadVariables(for: file.id)
        for variable in variables where variable.isSecret {
            let keychainKey = "envfile.\(file.id).\(variable.key)"
            await keychain.delete(key: keychainKey)
        }
        try await AppDatabase.shared.write { db in
            try EnvVariable.filter(Column("envFileId") == file.id).deleteAll(db)
            try file.delete(db)
        }
    }

    func saveVariable(_ variable: EnvVariable) async throws {
        if variable.isSecret {
            let keychainKey = "envfile.\(variable.envFileId).\(variable.key)"
            try await keychain.set(variable.value, forKey: keychainKey)
            var nonSecret = variable
            nonSecret.value = ""
            try await AppDatabase.shared.write { db in
                try nonSecret.save(db)
            }
        } else {
            try await AppDatabase.shared.write { db in
                try variable.save(db)
            }
        }
    }

    func deleteVariable(_ variable: EnvVariable) async throws {
        if variable.isSecret {
            let keychainKey = "envfile.\(variable.envFileId).\(variable.key)"
            await keychain.delete(key: keychainKey)
        }
        try await AppDatabase.shared.write { db in
            try variable.delete(db)
        }
    }

    func resolveSecretValue(_ variable: EnvVariable) async throws -> String {
        guard variable.isSecret else { return variable.value }
        let keychainKey = "envfile.\(variable.envFileId).\(variable.key)"
        return try await keychain.get(keychainKey) ?? ""
    }

    func importFromFile(url: URL, envFileId: String) async throws -> [EnvVariable] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let variables = try parseEnvContent(content, envFileId: envFileId)
        for var variable in variables {
            try await saveVariable(variable)
        }
        return variables
    }

    func exportToEnvFormat(variables: [EnvVariable]) async throws -> String {
        var result = ""
        for var variable in variables {
            if variable.isSecret {
                variable.value = try await resolveSecretValue(variable)
            }
            if variable.value.contains(" ") || variable.value.contains("#") {
                result += "\(variable.key)=\"\(variable.value)\"\n"
            } else {
                result += "\(variable.key)=\(variable.value)\n"
            }
        }
        return result
    }

    func exportToDockerFormat(variables: [EnvVariable]) async throws -> String {
        var result = ""
        for var variable in variables {
            if variable.isSecret {
                variable.value = try await resolveSecretValue(variable)
            }
            result += "\(variable.key)=\(variable.value)\n"
        }
        return result
    }

    func exportToShellFormat(variables: [EnvVariable]) async throws -> String {
        var result = ""
        for var variable in variables {
            if variable.isSecret {
                variable.value = try await resolveSecretValue(variable)
            }
            if variable.value.contains(" ") {
                result += "export \(variable.key)=\"\(variable.value)\"\n"
            } else {
                result += "export \(variable.key)=\(variable.value)\n"
            }
        }
        return result
    }

    private func parseEnvContent(_ content: String, envFileId: String) throws -> [EnvVariable] {
        var variables: [EnvVariable] = []
        var currentKey = ""
        var currentValue = ""
        var isMultiline = false

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmed
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if isMultiline {
                if trimmed.hasSuffix("\"") {
                    currentValue += "\n" + trimmed.dropLast()
                    let variable = EnvVariable(
                        envFileId: envFileId,
                        key: currentKey,
                        value: resolveVariables(currentValue, variables: variables),
                        isSecret: false
                    )
                    variables.append(variable)
                    isMultiline = false
                } else {
                    currentValue += "\n" + trimmed
                }
                continue
            }

            let parts = trimmed.split(separator: "=", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            currentKey = String(parts[0]).trimmed
            var rawValue = String(parts[1]).trimmed

            if rawValue.hasPrefix("\"") && rawValue.hasSuffix("\"") {
                rawValue = String(rawValue.dropFirst().dropLast())
            } else if rawValue.hasPrefix("\"") {
                currentValue = String(rawValue.dropFirst())
                isMultiline = true
                continue
            } else if rawValue.hasPrefix("'") && rawValue.hasSuffix("'") {
                rawValue = String(rawValue.dropFirst().dropLast())
            }

            let resolved = resolveVariables(rawValue, variables: variables)
            let variable = EnvVariable(
                envFileId: envFileId,
                key: currentKey,
                value: resolved,
                isSecret: false
            )
            variables.append(variable)
        }
        return variables
    }

    private func resolveVariables(_ value: String, variables: [EnvVariable]) -> String {
        var result = value
        let pattern = #"\$\{?([a-zA-Z_][a-zA-Z0-9_]*)\}?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            let varRange = Range(match.range(at: 1), in: result)!
            let varName = String(result[varRange])
            if let envVar = variables.first(where: { $0.key == varName }) {
                result.replaceSubrange(Range(match.range, in: result)!, with: envVar.value)
            } else if let envValue = ProcessInfo.processInfo.environment[varName] {
                result.replaceSubrange(Range(match.range, in: result)!, with: envValue)
            }
        }
        return result
    }
}
