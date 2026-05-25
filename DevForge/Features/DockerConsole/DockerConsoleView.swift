import SwiftUI

struct DockerConsoleView: View {
    @State private var containers: [DockerContainer] = []
    @State private var images: [DockerImage] = []
    @State private var dockerRunning = false
    @State private var selectedTab = 0
    @State private var selectedContainer: DockerContainer?
    @State private var showContainerDetail = false
    @State private var composeFileURL: URL?
    @State private var composeServices: [DockerComposeService.ComposeService] = []
    @State private var showLogs = false
    @State private var logContent: [String] = []
    @State private var logTask: Task<Void, Never>?
    @State private var error: ErrorMessage?

    var body: some View {
        VStack(spacing: 0) {
            if !dockerRunning {
                EmptyStateView(
                    icon: "shippingbox.fill",
                    title: "Docker Not Detected",
                    message: "Docker daemon is not running. Start Docker Desktop and try again."
                )
            } else {
                VStack(spacing: Spacing.md) {
                    Picker("", selection: $selectedTab) {
                        Text("Containers").tag(0)
                        Text("Images").tag(1)
                        Text("Compose").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 400)
                    .padding(.top, Spacing.sm)
                    
                    TabView(selection: $selectedTab) {
                        containersView.tag(0)
                        imagesView.tag(1)
                        composeView.tag(2)
                    }
                    .tabViewStyle(.automatic)
                }
                .padding(.horizontal)
            }
        }
        .task { await checkDocker() }
        .alert(item: $error) { err in
            Alert(title: Text("Error"), message: Text(err.message))
        }
    }

    private func checkDocker() async {
        dockerRunning = await DockerSocketService.shared.checkDockerRunning()
        if dockerRunning {
            await loadData()
        }
    }

    private func loadData() async {
        do {
            containers = try await DockerSocketService.shared.listContainers(all: true)
            images = try await DockerSocketService.shared.listImages()
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private var containersView: some View {
        List(containers) { container in
            HStack(spacing: Spacing.sm) {
                containerStatusBadge(container.state)
                
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(container.displayName)
                        .font(.appBody.bold())
                    Text(container.image)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(container.status)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, Spacing.xs)
                
                HStack(spacing: Spacing.xs) {
                    ActionButton(title: "Start", icon: "play.fill", color: .statusGreen) {
                        Task {
                            do {
                                try await DockerSocketService.shared.startContainer(id: container.id)
                                await loadData()
                            } catch { self.error = ErrorMessage(message: error.localizedDescription) }
                        }
                    }
                    .disabled(container.state == "running")
                    
                    ActionButton(title: "Stop", icon: "stop.fill", color: .statusRed) {
                        Task {
                            do {
                                try await DockerSocketService.shared.stopContainer(id: container.id)
                                await loadData()
                            } catch { self.error = ErrorMessage(message: error.localizedDescription) }
                        }
                    }
                    .disabled(container.state != "running")
                    
                    ActionButton(title: "Logs", icon: "terminal", color: .appAccent) {
                        selectedContainer = container
                        showLogs = true
                        logTask?.cancel()
                        logContent = []
                        logTask = Task {
                            let stream = await DockerSocketService.shared.containerLogs(id: container.id)
                            for await line in stream {
                                guard !Task.isCancelled else { break }
                                logContent.append(line)
                                if logContent.count > 10000 {
                                    logContent.removeFirst(logContent.count - 5000)
                                }
                            }
                        }
                    }
                    
                    ActionButton(title: "Inspect", icon: "info.circle", color: .statusGray) {
                        selectedContainer = container
                        showContainerDetail = true
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.sm)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showContainerDetail) {
            if let container = selectedContainer {
                ContainerDetailSheet(containerID: container.id)
            }
        }
        .sheet(isPresented: $showLogs) {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Circle().fill(Color.yellow).frame(width: 8, height: 8)
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                    }
                    .padding(.trailing, 8)
                    
                    Text("Container Logs: \(selectedContainer?.displayName ?? "")")
                        .font(.appMonospaceSmall.bold())
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button(action: { showLogs = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.black.opacity(0.95))
                
                Divider().background(Color.statusGray.opacity(0.3))
                
                ScrollView {
                    Text(logContent.joined(separator: "\n"))
                        .font(.appMonospaceSmall)
                        .foregroundStyle(Color.statusGreen)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color.black)
            }
            .frame(width: 650, height: 450)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.statusGray.opacity(0.5), lineWidth: 1)
            )
            .onDisappear { logTask?.cancel() }
        }
        .toolbar {
            ToolbarItem {
                Button("Refresh") { Task { await loadData() } }
            }
        }
    }

    private var imagesView: some View {
        List(images) { image in
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(image.displayTag)
                        .font(.appBody.bold())
                    Text(image.shortId)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(image.sizeFormatted)
                    .font(.appCaption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.trailing, Spacing.xs)
                
                ActionButton(title: "Remove", icon: "trash", color: .statusRed) {
                    Task {
                        do {
                            try await DockerSocketService.shared.removeImage(id: image.id)
                            await loadData()
                        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.sm)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var composeView: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Docker Compose")
                        .font(.appHeadline)
                    if let composeFileURL {
                        Text(composeFileURL.path)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No file selected")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    ActionButton(title: "Open File", icon: "doc.text.magnifyingglass", color: .appAccent) {
                        openComposeFile()
                    }
                    if composeFileURL != nil {
                        ActionButton(title: "Up", icon: "arrow.up.circle", color: .statusGreen) {
                            runComposeUp()
                        }
                        ActionButton(title: "Down", icon: "arrow.down.circle", color: .statusRed) {
                            runComposeDown()
                        }
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
            .padding(.vertical, Spacing.sm)
            
            if composeServices.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "Docker Compose",
                    message: "Open a docker-compose.yml file to view and manage services."
                )
            } else {
                List(composeServices) { service in
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(service.name)
                                .font(.appBody.bold())
                            if let image = service.image {
                                Text(image)
                                    .font(.appCaption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.sm)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func openComposeFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.yaml]
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            composeFileURL = url
            Task {
                do {
                    composeServices = try await DockerComposeService.shared.parseComposeFile(url: url)
                } catch { self.error = ErrorMessage(message: error.localizedDescription) }
            }
        }
    }

    private func runComposeUp() {
        guard let url = composeFileURL else { return }
        Task {
            do {
                _ = try await DockerComposeService.shared.runUp(composeFileURL: url)
            } catch { self.error = ErrorMessage(message: error.localizedDescription) }
        }
    }

    private func runComposeDown() {
        guard let url = composeFileURL else { return }
        Task {
            do {
                _ = try await DockerComposeService.shared.runDown(composeFileURL: url)
            } catch { self.error = ErrorMessage(message: error.localizedDescription) }
        }
    }

    private func containerStatusBadge(_ state: String) -> some View {
        let color: Color = state == "running" ? .statusGreen : (state == "paused" ? .statusYellow : .statusGray)
        return Text(state.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}

struct ContainerDetailSheet: View {
    let containerID: String
    @State private var detail: DockerContainerDetail?
    @State private var error: ErrorMessage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let detail {
                    Form {
                        LabeledContent("ID", value: detail.id.prefix(12).description)
                        LabeledContent("Name", value: detail.name.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
                        LabeledContent("Status", value: detail.state.status ?? "\u{2014}")
                        LabeledContent("Running", value: detail.state.running == true ? "Yes" : "No")
                        LabeledContent("Started", value: detail.state.startedAt ?? "\u{2014}")
                        LabeledContent("Finished", value: detail.state.finishedAt ?? "\u{2014}")
                        if let config = detail.config {
                            LabeledContent("Image", value: config.image ?? "\u{2014}")
                        }
                    }
                    .formStyle(.grouped)
                } else {
                    ProgressView("Loading...")
                }
            }
            .task {
                do {
                    detail = try await DockerSocketService.shared.inspectContainer(id: containerID)
                } catch { self.error = ErrorMessage(message: error.localizedDescription) }
            }
            .toolbar { Button("Close") { dismiss() } }
            .frame(width: 450, height: 350)
        }
    }
}
