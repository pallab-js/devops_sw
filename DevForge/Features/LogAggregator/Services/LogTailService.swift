import Foundation

actor LogTailService {
    static let shared = LogTailService()

    private var fileOffsets: [String: UInt64] = [:]
    private var activeFiles: Set<String> = []

    func tail(file url: URL) -> AsyncStream<LogLine> {
        let (stream, continuation) = AsyncStream<LogLine>.makeStream()
        let key = url.path
        activeFiles.insert(key)

        let fileHandle = try? FileHandle(forReadingFrom: url)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: key)[.size] as? UInt64) ?? 0

        if let currentOffset = fileOffsets[key] {
            fileHandle?.seek(toFileOffset: currentOffset)
        } else if fileSize > 100_000_000 {
            fileHandle?.seekToEndOfFile()
            let seekOffset = max(fileSize - 500_000, 0)
            fileHandle?.seek(toFileOffset: seekOffset)
            var lineCount = 0
            while lineCount < 10000 {
                guard let data = fileHandle?.readData(ofLength: 4096),
                      !data.isEmpty else { break }
                if let content = String(data: data, encoding: .utf8) {
                    lineCount += content.filter { $0 == "\n" }.count
                }
            }
        }

        let queue = DispatchQueue(label: "com.devforge.logtail.\(key)")
        var lineNumber = 0

        let watcher = FileWatcherService.shared
        Task {
            let stream = await watcher.watch(url: url)
            for await changedURL in stream {
                guard self.activeFiles.contains(key) else { break }
                let data = fileHandle?.readDataToEndOfFile() ?? Data()
                guard !data.isEmpty else { continue }
                if let content = String(data: data, encoding: .utf8) {
                    let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
                    for line in lines {
                        lineNumber += 1
                        continuation.yield(LogLine(
                            content: line,
                            timestamp: Date(),
                            isError: line.hasPrefix("ERROR") || line.contains("error"),
                            source: url.lastPathComponent
                        ))
                    }
                }
                if let offset = fileHandle?.offsetInFile {
                    self.fileOffsets[key] = offset
                }
            }
        }

        continuation.onTermination = { [weak self] _ in
            Task { [weak self] in
                await self?.stopTailing(file: url)
            }
        }

        return stream
    }

    func stopTailing(file url: URL) {
        let key = url.path
        activeFiles.remove(key)
        Task { await FileWatcherService.shared.stopWatching(url: url) }
    }
}
