import Foundation

actor DockerSocketService {
    static let shared = DockerSocketService()
    private let socketPath = "/var/run/docker.sock"

    private init() {}

    func checkDockerRunning() -> Bool {
        FileManager.default.fileExists(atPath: socketPath)
    }

    func listContainers(all: Bool = false) async throws -> [DockerContainer] {
        let params = all ? "?all=true" : ""
        let data = try await request(path: "/containers/json\(params)")
        return try JSONDecoder().decode([DockerContainer].self, from: data)
    }

    func listImages() async throws -> [DockerImage] {
        let data = try await request(path: "/images/json")
        return try JSONDecoder().decode([DockerImage].self, from: data)
    }

    func startContainer(id: String) async throws {
        _ = try await request(path: "/containers/\(id)/start", method: "POST")
    }

    func stopContainer(id: String) async throws {
        _ = try await request(path: "/containers/\(id)/stop", method: "POST")
    }

    func removeContainer(id: String, force: Bool = false) async throws {
        let params = force ? "?force=true" : ""
        _ = try await request(path: "/containers/\(id)\(params)", method: "DELETE")
    }

    func removeImage(id: String, force: Bool = false) async throws {
        let params = force ? "?force=true" : ""
        _ = try await request(path: "/images/\(id)\(params)", method: "DELETE")
    }

    func inspectContainer(id: String) async throws -> DockerContainerDetail {
        let data = try await request(path: "/containers/\(id)/json")
        return try JSONDecoder().decode(DockerContainerDetail.self, from: data)
    }

    func containerLogs(id: String, tail: Int = 100) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                do {
                    let path = "/containers/\(id)/logs?stdout=true&stderr=true&tail=\(tail)&follow=true"
                    let (raw, _) = try await rawRequest(path: path)
                    if let content = String(data: raw, encoding: .utf8) {
                        for line in content.components(separatedBy: "\n").filter({ !$0.isEmpty }) {
                            continuation.yield(String(line.dropFirst(8)))
                        }
                    }
                } catch {
                    continuation.yield("Error: \(error.localizedDescription)")
                }
                continuation.finish()
            }
        }
    }

    private func request(path: String, method: String = "GET") async throws -> Data {
        let (data, _) = try await rawRequest(path: path, method: method)
        return data
    }

    private func rawRequest(path: String, method: String = "GET") async throws -> (Data, Int) {
        guard checkDockerRunning() else {
            throw DockerError.daemonNotRunning
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [socketPath] in
                let fd = socket(AF_UNIX, SOCK_STREAM, 0)
                guard fd >= 0 else {
                    continuation.resume(throwing: DockerError.apiError("Failed to create socket"))
                    return
                }
                defer { close(fd) }

                var addr = sockaddr_un()
                addr.sun_family = sa_family_t(AF_UNIX)
                socketPath.withCString { strcpy(&addr.sun_path, $0) }

                let connectLen = socklen_t(MemoryLayout<sockaddr_un>.size)
                let connected = withUnsafeMutablePointer(to: &addr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                        connect(fd, sockaddrPtr, connectLen)
                    }
                }
                guard connected == 0 else {
                    continuation.resume(throwing: DockerError.daemonNotRunning)
                    return
                }

                let requestStr = "\(method) \(path) HTTP/1.1\r\nHost: localhost\r\nAccept: application/json\r\n\r\n"
                requestStr.withCString { ptr in
                    var totalSent = 0
                    let len = strlen(ptr)
                    while totalSent < len {
                        let sent = send(fd, ptr + totalSent, Int(len - totalSent), 0)
                        guard sent >= 0 else { break }
                        totalSent += sent
                    }
                }

                var responseData = Data()
                var buffer = [UInt8](repeating: 0, count: 65536)
                while true {
                    let n = read(fd, &buffer, buffer.count)
                    guard n > 0 else { break }
                    responseData.append(&buffer, count: n)
                }

                let responseStr = String(data: responseData, encoding: .utf8) ?? ""
                guard let headerEnd = responseStr.range(of: "\r\n\r\n") else {
                    continuation.resume(throwing: DockerError.apiError("Invalid HTTP response"))
                    return
                }

                let headerLines = String(responseStr[..<headerEnd.lowerBound]).components(separatedBy: "\r\n")
                guard let statusLine = headerLines.first,
                      let statusCode = Int(statusLine.split(separator: " ").dropFirst().first ?? "") else {
                    continuation.resume(throwing: DockerError.apiError("Invalid HTTP status"))
                    return
                }

                let bodyStr = String(responseStr[headerEnd.upperBound...])
                let body = Data(bodyStr.utf8)

                guard (200...299).contains(statusCode) else {
                    let msg = String(data: body, encoding: .utf8) ?? ""
                    continuation.resume(throwing: DockerError.apiError("HTTP \(statusCode): \(msg)"))
                    return
                }

                continuation.resume(returning: (body, statusCode))
            }
        }
    }
}
