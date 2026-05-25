import Foundation
import GRDB

actor TaskRunnerService {
    static let shared = TaskRunnerService()

    private var runningTasks: [String: Process] = [:]
    private var continuations: [String: AsyncStream<TaskOutputLine>.Continuation] = [:]

    func run(
        task: DiscoveredTask,
        workingDirectory: String
    ) -> AsyncStream<TaskOutputLine> {
        let (stream, continuation) = AsyncStream<TaskOutputLine>.makeStream()
        let taskID = task.id.uuidString
        continuations[taskID] = continuation

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", task.command]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process.environment = ProcessInfo.processInfo.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        runningTasks[taskID] = process

        let taskName = task.name
        let taskRun = TaskRun(taskName: taskName, command: task.command, workingDirectory: workingDirectory)

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let content = String(data: data, encoding: .utf8) else { return }
            for line in content.components(separatedBy: "\n").filter({ !$0.isEmpty }) {
                continuation.yield(TaskOutputLine(
                    content: line,
                    isError: false,
                    timestamp: Date()
                ))
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let content = String(data: data, encoding: .utf8) else { return }
            for line in content.components(separatedBy: "\n").filter({ !$0.isEmpty }) {
                continuation.yield(TaskOutputLine(
                    content: line,
                    isError: true,
                    timestamp: Date()
                ))
            }
        }

        process.terminationHandler = { [weak self] proc in
            continuation.finish()
            Task { [weak self] in
                var run = taskRun
                run.endTime = Date()
                run.exitCode = proc.terminationStatus
                try? await AppDatabase.shared.write { db in
                    try run.insert(db)
                }
                await self?.pruneHistory(taskName: taskName)
                await self?.cleanup(taskID: taskID)
            }
        }

        do {
            try process.run()
        } catch {
            continuation.finish()
            cleanup(taskID: taskID)
        }

        return stream
    }

    func cancel(taskID: String) {
        runningTasks[taskID]?.terminate()
        runningTasks.removeValue(forKey: taskID)
        continuations[taskID]?.finish()
        continuations.removeValue(forKey: taskID)
    }

    func cancelAll() {
        for (id, process) in runningTasks {
            process.terminate()
            continuations[id]?.finish()
        }
        runningTasks.removeAll()
        continuations.removeAll()
    }

    private func cleanup(taskID: String) {
        runningTasks.removeValue(forKey: taskID)
        continuations.removeValue(forKey: taskID)
    }

    func getHistory(taskName: String) async throws -> [TaskRun] {
        try await AppDatabase.shared.read { db in
            try TaskRun
                .filter(Column("taskName") == taskName)
                .order(Column("startTime").desc)
                .limit(50)
                .fetchAll(db)
        }
    }

    private func pruneHistory(taskName: String) async {
        do {
            try await AppDatabase.shared.write { db in
                let count = try TaskRun.filter(Column("taskName") == taskName).fetchCount(db)
                if count > 50 {
                    let ids = try TaskRun
                        .filter(Column("taskName") == taskName)
                        .order(Column("startTime").asc)
                        .limit(count - 50)
                        .fetchAll(db)
                        .map(\.id)
                    try TaskRun.deleteAll(db, ids: ids)
                }
            }
        } catch {}
    }
}
