import Foundation

actor FileWatcherService {
    static let shared = FileWatcherService()

    private var watchers: [String: AsyncStream<URL>.Continuation] = [:]
    private var sources: [String: DispatchSourceFileSystemObject] = [:]

    func watch(url: URL) -> AsyncStream<URL> {
        let (stream, continuation) = AsyncStream<URL>.makeStream()
        let key = url.path
        watchers[key] = continuation

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            continuation.finish()
            return stream
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .write,
            queue: .global()
        )
        source.setEventHandler {
            continuation.yield(url)
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        sources[key] = source

        continuation.onTermination = { [weak self] _ in
            Task { [weak self] in
                await self?.stopWatching(url: url)
            }
        }

        return stream
    }

    func stopWatching(url: URL) {
        let key = url.path
        sources[key]?.cancel()
        sources.removeValue(forKey: key)
        watchers[key]?.finish()
        watchers.removeValue(forKey: key)
    }

    func stopAll() {
        for (key, source) in sources {
            source.cancel()
            watchers[key]?.finish()
        }
        sources.removeAll()
        watchers.removeAll()
    }
}
