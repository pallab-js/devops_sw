import Foundation

actor DockerSocketService {
    static let shared = DockerSocketService()
    private let socketPath = "/var/run/docker.sock"
    private let version = "v1.43"

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

    func inspectContainer(id: String) async throws -> DockerContainerDetail {
        let data = try await request(path: "/containers/\(id)/json")
        return try JSONDecoder().decode(DockerContainerDetail.self, from: data)
    }

    func containerLogs(id: String, tail: Int = 100) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                do {
                    let params = "?stdout=true&stderr=true&tail=\(tail)&follow=true"
                    let data = try await request(path: "/containers/\(id)/logs\(params)")
                    if let content = String(data: data, encoding: .utf8) {
                        for line in content.components(separatedBy: "\n").filter({ !$0.isEmpty }) {
                            continuation.yield(line)
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
        guard checkDockerRunning() else {
            throw DockerError.daemonNotRunning
        }
        let url = URL(string: "http://localhost\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = [:]
        config.timeoutIntervalForRequest = 30

        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DockerError.apiError("Invalid response")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw DockerError.apiError("HTTP \(httpResponse.statusCode)")
        }
        return data
    }
}
