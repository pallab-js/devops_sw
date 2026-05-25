import Foundation

actor DataExporter {
    static let shared = DataExporter()

    func exportAll(to url: URL) async throws {
        var export: [String: Any] = [:]

        let processes: [ProcessRecord] = try await AppDatabase.shared.read { db in
            try ProcessRecord.fetchAll(db)
        }
        let processesData = try processes.map { try JSONEncoder().encode($0) }
        export["processes"] = processesData

        let envFiles: [EnvFile] = try await AppDatabase.shared.read { db in
            try EnvFile.fetchAll(db)
        }
        let envFilesData = try envFiles.map { try JSONEncoder().encode($0) }
        export["envFiles"] = envFilesData

        let repos: [GitRepository] = try await AppDatabase.shared.read { db in
            try GitRepository.fetchAll(db)
        }
        let reposData = try repos.map { try JSONEncoder().encode($0) }
        export["repositories"] = reposData

        let jsonData = try JSONSerialization.data(withJSONObject: export, options: .prettyPrinted)
        try jsonData.write(to: url, options: .atomic)
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
