import Foundation

actor ProcessService {
    static let shared = ProcessService()

    private var runningProcesses: [String: Process] = [:]
    private var continuations: [String: AsyncStream<LogLine>.Continuation] = [:]
    private var streams: [String: AsyncStream<LogLine>] = [:]

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
        updatedRecord.status = .running
        updatedRecord.lastStartedAt = Date()

        let (stream, continuation) = AsyncStream<LogLine>.makeStream()
        continuations[recordID] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { [weak self] in
                await self?.cleanup(recordID: recordID)
            }
        }
        streams[recordID] = stream

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

        let terminationContinuation = AsyncStream<Void>.makeStream()
        process.terminationHandler = { [weak self] proc in
            Task { [weak self] in
                await self?.handleTermination(recordID: recordID, terminationStatus: proc.terminationStatus)
                continuation.finish()
                terminationContinuation.continuation.finish()
            }
        }

        try process.run()
        updatedRecord.pid = process.processIdentifier
        try await database.write { db in
            try updatedRecord.save(db)
        }
        return updatedRecord
    }

    func terminate(recordID: String) async {
        guard let process = runningProcesses[recordID] else { return }
        process.terminate()
        Task { [weak self, process] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let self = self else { return }
            let stillActive = await self.isProcessActive(recordID)
            if process.isRunning && stillActive {
                process.terminate()
            }
        }
    }

    private func isProcessActive(_ recordID: String) -> Bool {
        runningProcesses[recordID] != nil
    }

    func waitForTermination(recordID: String) async {
        while runningProcesses[recordID] != nil {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    func runningCount() -> Int {
        runningProcesses.count
    }

    func observe(recordID: String) -> AsyncStream<LogLine>? {
        streams[recordID]
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
                    record.status = status
                    record.pid = nil
                    try record.save(db)
                }
            }
        }
    }

    private func cleanup(recordID: String) {
        runningProcesses.removeValue(forKey: recordID)
        continuations.removeValue(forKey: recordID)
        streams.removeValue(forKey: recordID)
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
