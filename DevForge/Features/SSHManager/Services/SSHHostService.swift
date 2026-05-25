import Foundation
import Network

actor SSHHostService {
    static let shared = SSHHostService()

    func loadHosts() async throws -> [SSHHost] {
        try await SSHConfigParser.shared.loadHosts()
    }

    func saveHosts(_ hosts: [SSHHost]) async throws {
        try await SSHConfigParser.shared.saveHosts(hosts)
    }

    func ensureConfig() async throws {
        try await SSHConfigParser.shared.ensureConfigExists()
    }

    func testConnectivity(host: SSHHost) async -> Bool {
        await withCheckedContinuation { continuation in
            let conn = NWConnection(
                host: NWEndpoint.Host(host.hostname),
                port: NWEndpoint.Port(rawValue: UInt16(host.port)) ?? 22,
                using: .tcp
            )
            conn.stateUpdateHandler = { state in
                if state == .ready {
                    conn.cancel()
                    continuation.resume(returning: true)
                } else if case .failed = state {
                    conn.cancel()
                    continuation.resume(returning: false)
                }
            }
            conn.start(queue: .global())
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                conn.cancel()
                continuation.resume(returning: false)
            }
        }
    }

    func openTerminal(host: SSHHost) {
        let cmd = host.sshCommand
        let script = "tell application \"Terminal\" to do script \"\(cmd.replacingOccurrences(of: "\"", with: "\\\""))\""
        guard let appleScript = NSAppleScript(source: script) else { return }
        appleScript.executeAndReturnError(nil)
    }
}
