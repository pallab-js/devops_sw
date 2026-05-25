import SwiftUI

struct EnvVaultPlaceholder: View {
    var body: some View {
        EmptyStateView(
            icon: "lock.shield.fill",
            title: "Environment & Secrets Vault",
            message: "Manage .env files and secret variables securely."
        )
    }
}

struct DockerConsolePlaceholder: View {
    var body: some View {
        EmptyStateView(
            icon: "shippingbox.fill",
            title: "Docker Console",
            message: "Manage containers, images, and compose projects."
        )
    }
}

struct GitWorkspacePlaceholder: View {
    var body: some View {
        EmptyStateView(
            icon: "arrow.triangle.branch",
            title: "Git Workspace Manager",
            message: "Monitor and manage multiple Git repositories."
        )
    }
}

struct SSHManagerPlaceholder: View {
    var body: some View {
        EmptyStateView(
            icon: "network",
            title: "SSH & Host Manager",
            message: "Manage SSH configs and connections."
        )
    }
}

struct TaskRunnerPlaceholder: View {
    var body: some View {
        EmptyStateView(
            icon: "play.circle.fill",
            title: "Task Runner",
            message: "Run Makefile, package.json scripts, and Justfile tasks."
        )
    }
}

struct LogAggregatorPlaceholder: View {
    var body: some View {
        EmptyStateView(
            icon: "doc.text.magnifyingglass",
            title: "Log Aggregator",
            message: "Tail and search log files across your system."
        )
    }
}

struct SystemHealthPlaceholder: View {
    var body: some View {
        EmptyStateView(
            icon: "gauge.with.dots.needle.33percent",
            title: "System Health Dashboard",
            message: "Monitor CPU, memory, disk, and network."
        )
    }
}
