import Foundation
import GRDB
import SwiftUI

struct DatabaseKey: EnvironmentKey {
    static let defaultValue: AppDatabase = AppDatabase.shared
}

extension EnvironmentValues {
    var database: AppDatabase {
        get { self[DatabaseKey.self] }
        set { self[DatabaseKey.self] = newValue }
    }
}

final class AppDatabase: Sendable {
    static let shared = AppDatabase()

    private let dbPool: DatabasePool

    private init() {
        let url = Self.databaseURL()
        dbPool = try! DatabasePool(path: url.path)
        try! migrator.migrate(dbPool)
    }

    static func databaseURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let directory = appSupport.appendingPathComponent("com.devforge.app", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("devforge.sqlite")
    }

    var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_initial_schema") { db in
            try db.create(table: "processRecord") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("command", .text).notNull()
                t.column("workingDirectory", .text).notNull()
                t.column("environmentVariables", .text).notNull()
                t.column("pid", .integer)
                t.column("status", .text).notNull()
                t.column("createdAt", .text).notNull()
                t.column("lastStartedAt", .text)
            }
            try db.create(table: "processTemplate") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("command", .text).notNull()
                t.column("workingDirectory", .text).notNull()
                t.column("environmentVariables", .text).notNull()
            }
            try db.create(table: "envFile") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("projectPath", .text).notNull()
                t.column("createdAt", .text).notNull()
            }
            try db.create(table: "envVariable") { t in
                t.column("id", .text).primaryKey()
                t.column("envFileId", .text).notNull().references("envFile", onDelete: .cascade)
                t.column("key", .text).notNull()
                t.column("value", .text).notNull()
                t.column("isSecret", .integer).notNull()
                t.column("desc", .text).notNull()
            }
            try db.create(table: "taskRun") { t in
                t.column("id", .text).primaryKey()
                t.column("taskName", .text).notNull()
                t.column("command", .text).notNull()
                t.column("workingDirectory", .text).notNull()
                t.column("startTime", .text).notNull()
                t.column("endTime", .text)
                t.column("exitCode", .integer)
            }
        }
        return migrator
    }

    func write<T>(_ block: @escaping (Database) throws -> T) async throws -> T {
        try await dbPool.write(block)
    }

    func read<T>(_ block: @escaping (Database) throws -> T) async throws -> T {
        try await dbPool.read(block)
    }

    func observation<R: ValueReducer>(_ observation: ValueObservation<R>) -> AsyncValueObservation<R.Value> {
        observation.values(in: dbPool)
    }
}
