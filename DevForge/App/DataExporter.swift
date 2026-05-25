import Foundation

actor DataExporter {
    static let shared = DataExporter()

    func exportAllData() async throws -> Data {
        var export: [String: Any] = [:]

        let processes: [ProcessRecord] = try await AppDatabase.shared.read { db in
            try ProcessRecord.fetchAll(db)
        }
        export["processes"] = processes.map { try? JSONEncoder().encode($0) }

        let envFiles: [EnvFile] = try await AppDatabase.shared.read { db in
            try EnvFile.fetchAll(db)
        }
        export["envFiles"] = envFiles.map { try? JSONEncoder().encode($0) }

        let repos: [GitRepository] = try await AppDatabase.shared.read { db in
            try GitRepository.fetchAll(db)
        }
        export["repositories"] = repos.map { try? JSONEncoder().encode($0) }

        return try JSONSerialization.data(withJSONObject: export, options: .prettyPrinted)
    }

    func importData(from url: URL) async throws {
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.unknown(DataImportError.invalidFormat)
        }

        if let processesData = json["processes"] as? [Data] {
            for pData in processesData {
                if let process = try? JSONDecoder().decode(ProcessRecord.self, from: pData) {
                    try await AppDatabase.shared.write { db in
                        try process.save(db)
                    }
                }
            }
        }
    }

    enum DataImportError: Error {
        case invalidFormat
    }
}
