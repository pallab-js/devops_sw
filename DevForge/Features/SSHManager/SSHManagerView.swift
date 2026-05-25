import SwiftUI
import Network

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
                    message: "Select or add an SSH host."
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
            HStack {
                Circle()
                    .fill(reachability[host.id] == true ? Color.statusGreen :
                          reachability[host.id] == false ? Color.statusRed : Color.statusGray)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading) {
                    Text(host.alias).font(.appBody)
                    Text("\(host.user)@\(host.hostname)").font(.appCaption).foregroundStyle(.secondary)
                }
            }
            .tag(host)
        }
        .listStyle(.inset)
        .toolbar {
            ToolbarItem { Button(action: { showAddHost = true }) { Label("Add", systemImage: "plus") } }
        }
    }

    private func hostDetail(host: SSHHost) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(host.alias).font(.appHeadline)
                Spacer()
                Button("Test") { Task { await testConnectivity(host: host) } }
                Button("Connect") { openTerminal(host: host) }
            }
            .padding()
            Form {
                LabeledContent("Hostname", value: host.hostname)
                LabeledContent("User", value: host.user)
                LabeledContent("Port", value: "\(host.port)")
                LabeledContent("Identity File", value: host.identityFile.isEmpty ? "—" : host.identityFile)
                LabeledContent("Proxy Jump", value: host.proxyJump.isEmpty ? "—" : host.proxyJump)
                LabeledContent("Forward Agent", value: host.forwardAgent ? "Yes" : "No")
            }
            .formStyle(.grouped)
            Divider()
            portForwardSection
        }
    }

    private var portForwardSection: some View {
        VStack(alignment: .leading) {
            Text("Port Forwards").font(.appHeadline).padding()
            List {
                ForEach(portForwards) { rule in
                    HStack {
                        Text("localhost:\(rule.localPort) → \(rule.remoteHost):\(rule.remotePort)")
                            .font(.appMonospaceSmall)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { rule.isActive },
                            set: { _ in toggleForward(rule) }
                        ))
                    }
                }
            }
        }
    }

    private func loadHosts() async {
        do {
            hosts = try await SSHConfigParser.shared.loadHosts()
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func addHost(_ host: SSHHost) async {
        hosts.append(host)
        do {
            try await SSHConfigParser.shared.saveHosts(hosts)
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func testConnectivity(host: SSHHost) async {
        let conn = NWConnection(
            host: NWEndpoint.Host(host.hostname),
            port: NWEndpoint.Port(rawValue: UInt16(host.port)) ?? 22,
            using: .tcp
        )
        conn.stateUpdateHandler = { state in
            if state == .ready {
                Task { @MainActor in
                    self.reachability[host.id] = true
                }
                conn.cancel()
            } else {
                Task { @MainActor in
                    self.reachability[host.id] = false
                }
            }
        }
        conn.start(queue: .global())
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        conn.cancel()
    }

    private func openTerminal(host: SSHHost) {
        Task { await SSHHostService.shared.openTerminal(host: host) }
    }

    private func toggleForward(_ rule: PortForwardRule) {
        // toggle port forward via process
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
