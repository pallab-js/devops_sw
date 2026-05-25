import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case processManager = "Process Manager"
    case envVault = "Env Vault"
    case dockerConsole = "Docker Console"
    case gitWorkspace = "Git Workspace"
    case sshManager = "SSH Manager"
    case taskRunner = "Task Runner"
    case logAggregator = "Log Aggregator"
    case systemHealth = "System Health"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .processManager: "terminal.fill"
        case .envVault: "lock.shield.fill"
        case .dockerConsole: "shippingbox.fill"
        case .gitWorkspace: "arrow.triangle.branch"
        case .sshManager: "network"
        case .taskRunner: "play.circle.fill"
        case .logAggregator: "doc.text.magnifyingglass"
        case .systemHealth: "gauge.with.dots.needle.33percent"
        }
    }
}

struct ContentView: View {
    @State private var selectedSection: AppSection? = .processManager

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
    }

    private var sidebar: some View {
        List(AppSection.allCases, selection: $selectedSection) { section in
            Label(section.rawValue, systemImage: section.icon)
                .tag(section)
        }
        .navigationSplitViewColumnWidth(220)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .processManager:
            ProcessManagerView()
        case .envVault:
            EnvVaultView()
        case .dockerConsole:
            DockerConsoleView()
        case .gitWorkspace:
            GitWorkspaceView()
        case .sshManager:
            SSHManagerView()
        case .taskRunner:
            TaskRunnerView()
        case .logAggregator:
            LogAggregatorView()
        case .systemHealth:
            SystemHealthView()
        case nil:
            Text("Select a section")
                .foregroundStyle(.secondary)
        }
    }
}
