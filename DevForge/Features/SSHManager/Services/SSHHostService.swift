import Foundation
import Network

private final class ConnectivityTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func performOnce(action: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        if !didResume {
            didResume = true
            action()
        }
    }
}

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
            let tracker = ConnectivityTracker()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    tracker.performOnce {
                        conn.cancel()
                        continuation.resume(returning: true)
                    }
                case .failed:
                    tracker.performOnce {
                        conn.cancel()
                        continuation.resume(returning: false)
                    }
                case .cancelled:
                    tracker.performOnce {
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }
            conn.start(queue: .global())

            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                tracker.performOnce {
                    conn.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func openTerminal(host: SSHHost) {
        let args = sshArgs(host: host)
        let escapedArgs = args.map { arg in
            arg.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
        }
        let cmdStr = escapedArgs.joined(separator: " ")
        let script = "tell application \"Terminal\" to do script \"\(cmdStr)\""
        guard let appleScript = NSAppleScript(source: script) else { return }
        appleScript.executeAndReturnError(nil)
    }

    private func sshArgs(host: SSHHost) -> [String] {
        var args = ["ssh"]
        if !host.identityFile.isEmpty {
            args.append("-i")
            args.append(host.identityFile)
        }
        if host.port != 22 {
            args.append("-p")
            args.append("\(host.port)")
        }
        if host.forwardAgent {
            args.append("-A")
        }
        if !host.proxyJump.isEmpty {
            args.append("-J")
            args.append(host.proxyJump)
        }
        args.append("\(host.user)@\(host.hostname)")
        return args
    }
}
