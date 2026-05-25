import Foundation
import GRDB

@Observable
final class ProcessManagerViewModel {
    var processes: [ProcessRecord] = []
    var selectedProcess: ProcessRecord?
    var logLines: [ProcessRecord: [LogLine]] = [:]
    var error: ErrorMessage?

    private let service = ProcessService.shared
    private let database = AppDatabase.shared

    func loadProcesses() async {
        do {
            processes = try await database.read { db in
                try ProcessRecord.order(Column("createdAt").desc).fetchAll(db)
            }
        } catch {
            self.error = ErrorMessage(message: error.localizedDescription)
        }
    }

    func saveProcess(_ record: ProcessRecord) async {
        do {
            try await database.write { db in
                try record.insert(db)
            }
            await loadProcesses()
        } catch {
            self.error = ErrorMessage(message: error.localizedDescription)
        }
    }

    func startProcess(_ record: ProcessRecord) async {
        do {
            let updated = try await service.spawn(record: record, database: database)
            if let idx = processes.firstIndex(where: { $0.id == updated.id }) {
                processes[idx] = updated
            }
        } catch {
            self.error = ErrorMessage(message: error.localizedDescription)
        }
    }

    func stopProcess(_ record: ProcessRecord) async {
        await service.terminate(recordID: record.id)
    }

    func deleteProcess(_ record: ProcessRecord) async {
        await service.terminate(recordID: record.id)
        do {
            try await database.write { db in
                try record.delete(db)
            }
            await loadProcesses()
        } catch {
            self.error = ErrorMessage(message: error.localizedDescription)
        }
    }

    func observeLogs(for record: ProcessRecord) -> AsyncStream<LogLine>? {
        nil
    }
}
