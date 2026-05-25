import Foundation

actor LogTailService {
    static let shared = LogTailService()

    private var fileOffsets: [String: UInt64] = [:]
    private var activeFiles: Set<String> = []
    private var fileHandles: [String: FileHandle] = [:]

    func tail(file url: URL) -> AsyncStream<LogLine> {
        let (stream, continuation) = AsyncStream<LogLine>.makeStream()
        let key = url.path
        activeFiles.insert(key)

        let fileHandle = try? FileHandle(forReadingFrom: url)
        fileHandles[key] = fileHandle
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: key)[.size] as? UInt64) ?? 0

        if let currentOffset = fileOffsets[key] {
            fileHandle?.seek(toFileOffset: currentOffset)
        } else if fileSize > 100_000_000 {
            fileHandle?.seekToEndOfFile()
            let seekOffset = max(fileSize - 500_000, 0)
            fileHandle?.seek(toFileOffset: seekOffset)
            var lineCount = 0
            var bytesRead: UInt64 = 0
            while lineCount < 10000 {
                guard let data = fileHandle?.readData(ofLength: 4096),
                      data.count > 0 else { break }
                bytesRead += UInt64(data.count)
                if let content = String(data: data, encoding: .utf8) {
                    lineCount += content.filter { $0 == "\n" }.count
                }
            }
            fileOffsets[key] = seekOffset + bytesRead
        }

        var lineNumber = 0

        let watcher = FileWatcherService.shared
        Task {
            let stream = await watcher.watch(url: url)
            for await _ in stream {
                guard self.activeFiles.contains(key) else { break }
                guard let fh = self.fileHandles[key] else { break }
                let data = fh.readDataToEndOfFile()
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
                self.fileOffsets[key] = fh.offsetInFile
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
        fileHandles[key]?.closeFile()
        fileHandles.removeValue(forKey: key)
        Task { await FileWatcherService.shared.stopWatching(url: url) }
    }
}
