import SwiftUI

struct SSHManagerView: View {
    @State private var hosts: [SSHHost] = []
    @State private var selectedHost: SSHHost?
    @State private var portForwards: [PortForwardRule] = []
    @State private var reachability: [String: Bool] = [:]
    @State private var showAddHost = false
    @State private var showEditHost = false
    @State private var error: ErrorMessage?

    var body: some View {
        HSplitView {
            hostList
                .frame(minWidth: 220)
            if let host = selectedHost {
                hostDetail(host: host)
            } else {
                EmptyStateView(
                    icon: "network",
                    title: "No Host Selected",
                    message: "Select or add an SSH host to manage."
                )
            }
        }
        .task { await loadHosts() }
        .sheet(isPresented: $showAddHost) {
            EditHostSheet { host in
                Task { await addHost(host) }
            }
        }
        .alert(item: $error) { err in
            Alert(title: Text("Error"), message: Text(err.message))
        }
    }

    private var hostList: some View {
        List(hosts, selection: $selectedHost) { host in
            HStack(spacing: Spacing.sm) {
                SignalIndicatorView(isOnline: reachability[host.id])
                
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(host.alias)
                        .font(.appBody.bold())
                    Text("\(host.user)@\(host.hostname)")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.vertical, Spacing.xxs)
            .tag(host)
        }
        .listStyle(.inset)
        .toolbar {
            ToolbarItem {
                Button(action: { showAddHost = true }) {
                    Label("Add", systemImage: "plus")
                }
            }
        }
    }

    private func hostDetail(host: SSHHost) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(host.alias)
                        .font(.appTitle3.bold())
                    Text("\(host.user)@\(host.hostname)")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                HStack(spacing: 8) {
                    ActionButton(title: "Test", icon: "bolt.fill", color: .statusYellow) {
                        Task { await testConnectivity(host: host) }
                    }
                    ActionButton(title: "Connect", icon: "terminal.fill", color: .statusGreen) {
                        openTerminal(host: host)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            .padding([.horizontal, .top])
            
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Connection Details")
                    .font(.appHeadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, Spacing.xxs)
                
                VStack(spacing: Spacing.xs) {
                    detailRow(label: "Hostname", value: host.hostname)
                    detailRow(label: "User", value: host.user)
                    detailRow(label: "Port", value: "\(host.port)")
                    detailRow(label: "Identity File", value: host.identityFile.isEmpty ? "\u{2014}" : host.identityFile)
                    detailRow(label: "Proxy Jump", value: host.proxyJump.isEmpty ? "\u{2014}" : host.proxyJump)
                    detailRow(label: "Forward Agent", value: host.forwardAgent ? "Yes" : "No")
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .padding()
            
            Divider()
            
            portForwardSection
        }
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.appCaption.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var portForwardSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Port Forwards")
                .font(.appHeadline)
                .padding(.horizontal)
                .padding(.top, Spacing.sm)
                
            if portForwards.isEmpty {
                Text("No port forwarding rules configured.")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, Spacing.md)
            } else {
                List {
                    ForEach(portForwards) { rule in
                        HStack {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                                    .font(.caption)
                                    .foregroundStyle(.purple)
                                Text("localhost:\(rule.localPort) \u{2192} \(rule.remoteHost):\(rule.remotePort)")
                                    .font(.appMonospaceSmall)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { rule.isActive },
                                set: { _ in toggleForward(rule) }
                            ))
                            .toggleStyle(.switch)
                        }
                        .padding(.vertical, Spacing.xs)
                        .padding(.horizontal, Spacing.sm)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.06), lineWidth: 1)
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func loadHosts() async {
        do {
            hosts = try await SSHHostService.shared.loadHosts()
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func addHost(_ host: SSHHost) async {
        hosts.append(host)
        do {
            try await SSHHostService.shared.saveHosts(hosts)
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func testConnectivity(host: SSHHost) async {
        reachability[host.id] = await SSHHostService.shared.testConnectivity(host: host)
    }

    private func openTerminal(host: SSHHost) {
        Task {
            await SSHHostService.shared.openTerminal(host: host)
        }
    }

    private func toggleForward(_ rule: PortForwardRule) {
        // toggle port forward via process
    }
}

struct SignalIndicatorView: View {
    let isOnline: Bool?
    
    var body: some View {
        let color: Color = {
            switch isOnline {
            case .some(true): return Color.statusGreen
            case .some(false): return Color.statusRed
            case .none: return Color.statusGray
            }
        }()
        
        return ZStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            if isOnline == true {
                Circle()
                    .stroke(color.opacity(0.4), lineWidth: 2)
                    .frame(width: 14, height: 14)
                    .scaleEffect(1.2)
            }
        }
        .frame(width: 16, height: 16)
    }
}

struct EditHostSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (SSHHost) -> Void

    @State private var alias = ""
    @State private var hostname = ""
    @State private var user = ""
    @State private var port = "22"
    @State private var identityFile = ""
    @State private var proxyJump = ""

    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("Add SSH Host").font(.appHeadline)
            Form {
                TextField("Alias", text: $alias)
                TextField("Hostname", text: $hostname)
                TextField("User", text: $user)
                TextField("Port", text: $port)
                TextField("Identity File", text: $identityFile)
                TextField("Proxy Jump", text: $proxyJump)
            }
            .formStyle(.grouped)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    let host = SSHHost(
                        alias: alias,
                        hostname: hostname,
                        user: user,
                        port: Int(port) ?? 22,
                        identityFile: identityFile,
                        proxyJump: proxyJump
                    )
                    onSave(host)
                    dismiss()
                }
                .disabled(alias.isEmpty || hostname.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }
}
