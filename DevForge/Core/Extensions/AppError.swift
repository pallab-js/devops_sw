import Foundation

enum AppError: LocalizedError {
    case database(Error)
    case process(String)
    case docker(DockerError)
    case permission(String)
    case keychain(String)
    case git(String)
    case ssh(String)
    case notFound(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .database(let e): return "Database error: \(e.localizedDescription)"
        case .process(let msg): return "Process error: \(msg)"
        case .docker(let e): return "Docker error: \(e.localizedDescription)"
        case .permission(let msg): return "Permission denied: \(msg)"
        case .keychain(let msg): return "Keychain error: \(msg)"
        case .git(let msg): return "Git error: \(msg)"
        case .ssh(let msg): return "SSH error: \(msg)"
        case .notFound(let msg): return "Not found: \(msg)"
        case .unknown(let e): return "Unexpected error: \(e.localizedDescription)"
        }
    }
}

enum DockerError: LocalizedError {
    case daemonNotRunning
    case containerNotFound(String)
    case imageNotFound(String)
    case apiError(String)
    case socketError(Error)

    var errorDescription: String? {
        switch self {
        case .daemonNotRunning: return "Docker daemon is not running"
        case .containerNotFound(let id): return "Container not found: \(id)"
        case .imageNotFound(let id): return "Image not found: \(id)"
        case .apiError(let msg): return "Docker API error: \(msg)"
        case .socketError(let e): return "Docker socket error: \(e.localizedDescription)"
        }
    }
}

struct ErrorMessage: Identifiable {
    let id = UUID()
    let message: String
}
