import Foundation

actor FileWatcherService {
    static let shared = FileWatcherService()

    private var watchers: [String: AsyncStream<URL>.Continuation] = [:]

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
        source.setEventHandler { [weak self] in
            continuation.yield(url)
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()

        continuation.onTermination = { _ in
            source.cancel()
        }

        return stream
    }

    func stopWatching(url: URL) {
        let key = url.path
        watchers[key]?.finish()
        watchers.removeValue(forKey: key)
    }

    func stopAll() {
        for (_, continuation) in watchers {
            continuation.finish()
        }
        watchers.removeAll()
    }
}
