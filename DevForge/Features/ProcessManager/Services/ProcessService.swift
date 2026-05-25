import Foundation

actor ProcessService {
    static let shared = ProcessService()

    private var runningProcesses: [String: Process] = [:]
    private var continuations: [String: AsyncStream<LogLine>.Continuation] = [:]

    func spawn(record: ProcessRecord, database: AppDatabase) async throws -> ProcessRecord {
        let process = Process()
        let commandParts = parseCommand(record.command)
        process.executableURL = URL(fileURLWithPath: commandParts.executable)
        process.arguments = commandParts.arguments
        process.currentDirectoryURL = URL(fileURLWithPath: record.workingDirectory)

        var env = ProcessInfo.processInfo.environment
        env.merge(record.environmentVariables) { _, new in new }
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var updatedRecord = record

        let recordID = record.id
        runningProcesses[recordID] = process
        updatedRecord.setRunning(pid: process.processIdentifier)

        let (stream, continuation) = AsyncStream<LogLine>.makeStream()
        continuations[recordID] = continuation

        Task { [weak self] in
            self?.readPipe(
                fileHandle: stdoutPipe.fileHandleForReading,
                isError: false,
                recordID: recordID,
                continuation: continuation
            )
        }
        Task { [weak self] in
            self?.readPipe(
                fileHandle: stderrPipe.fileHandleForReading,
                isError: true,
                recordID: recordID,
                continuation: continuation
            )
        }

        process.terminationHandler = { [weak self] proc in
            Task { [weak self] in
                await self?.handleTermination(recordID: recordID, terminationStatus: proc.terminationStatus)
                continuation.finish()
            }
        }

        try process.run()
        updatedRecord.pid = process.processIdentifier
        try await database.write { db in
            try updatedRecord.save(db)
        }
        return updatedRecord
    }

    func terminate(recordID: String) {
        guard let process = runningProcesses[recordID] else { return }
        process.terminate()
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if process.isRunning {
                process.terminate()
            }
        }
    }

    func observe(recordID: String) -> AsyncStream<LogLine>? {
        guard let continuation = continuations[recordID] else { return nil }
        let stream = AsyncStream<LogLine> { c in
            c.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.cleanup(recordID: recordID)
                }
            }
        }
        return stream
    }

    func processExists(recordID: String) -> Bool {
        runningProcesses[recordID] != nil
    }

    nonisolated private func readPipe(
        fileHandle: FileHandle,
        isError: Bool,
        recordID: String,
        continuation: AsyncStream<LogLine>.Continuation
    ) {
        fileHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let content = String(data: data, encoding: .utf8) else { return }
            let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            for line in lines {
                let logLine = LogLine(
                    content: line,
                    timestamp: Date(),
                    isError: isError,
                    source: recordID
                )
                continuation.yield(logLine)
            }
        }
    }

    private func handleTermination(recordID: String, terminationStatus: Int32) {
        runningProcesses.removeValue(forKey: recordID)
        let status: ProcessStatus = terminationStatus == 0 ? .stopped : .failed
        Task {
            try? await AppDatabase.shared.write { db in
                if var record = try? ProcessRecord.fetchOne(db, id: recordID) {
                    record.status = terminationStatus == 0 ? .stopped : .failed
                    record.pid = nil
                    try record.save(db)
                }
            }
        }
    }

    private func cleanup(recordID: String) {
        runningProcesses.removeValue(forKey: recordID)
        continuations.removeValue(forKey: recordID)
    }

    private func parseCommand(_ command: String) -> (executable: String, arguments: [String]) {
        let trimmed = command.trimmed
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("./") {
            var parts = trimmed.components(separatedBy: " ")
            let executable = parts.removeFirst()
            return (executable, parts)
        }
        if trimmed.contains(" ") {
            var parts = trimmed.components(separatedBy: " ")
            let executable = parts.removeFirst()
            return (executable, parts)
        }
        return (trimmed, [])
    }
}
