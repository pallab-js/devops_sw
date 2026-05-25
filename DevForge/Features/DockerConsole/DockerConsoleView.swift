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
    @State private var logStream: AsyncStream<String>?
    @State private var logContent: [String] = []
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
                Picker("", selection: $selectedTab) {
                    Text("Containers").tag(0)
                    Text("Images").tag(1)
                    Text("Compose").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                TabView(selection: $selectedTab) {
                    containersView.tag(0)
                    imagesView.tag(1)
                    composeView.tag(2)
                }
                .tabViewStyle(.automatic)
            }
        }
        .task { await checkDocker() }
        .alert(item: $error) { err in
            Alert(title: Text("Error"), message: Text(err.message))
        }
    }

    private func checkDocker() async {
        dockerRunning = DockerSocketService.shared.checkDockerRunning()
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
            HStack {
                statusDot(container.state)
                VStack(alignment: .leading) {
                    Text(container.displayName).font(.appBody)
                    Text(container.image).font(.appCaption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(container.status).font(.appCaption).foregroundStyle(.secondary)
                Button("Start") {
                    Task {
                        try? await DockerSocketService.shared.startContainer(id: container.id)
                        await loadData()
                    }
                }
                .disabled(container.state == "running")
                Button("Stop") {
                    Task {
                        try? await DockerSocketService.shared.stopContainer(id: container.id)
                        await loadData()
                    }
                }
                .disabled(container.state != "running")
                Button("Logs") {
                    selectedContainer = container
                    showLogs = true
                    Task {
                        logContent = []
                        let stream = DockerSocketService.shared.containerLogs(id: container.id)
                        for await line in stream {
                            logContent.append(line)
                        }
                    }
                }
                Button("Inspect") {
                    selectedContainer = container
                    showContainerDetail = true
                }
            }
        }
        .sheet(isPresented: $showContainerDetail) {
            if let container = selectedContainer {
                ContainerDetailSheet(containerID: container.id)
            }
        }
        .sheet(isPresented: $showLogs) {
            NavigationStack {
                ScrollView {
                    Text(logContent.joined(separator: "\n"))
                        .font(.appMonospaceSmall)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .toolbar { Button("Close") { showLogs = false } }
            }
            .frame(width: 600, height: 400)
        }
        .toolbar {
            ToolbarItem {
                Button("Refresh") { Task { await loadData() } }
            }
        }
    }

    private var imagesView: some View {
        List(images) { image in
            HStack {
                VStack(alignment: .leading) {
                    Text(image.displayTag).font(.appBody)
                    Text(image.shortId).font(.appCaption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(image.sizeFormatted).font(.appCaption)
                Button("Remove") {
                    Task {
                        try? await DockerSocketService.shared.removeContainer(id: image.id)
                        await loadData()
                    }
                }
            }
        }
    }

    private var composeView: some View {
        VStack {
            HStack {
                Button("Open Compose File") { openComposeFile() }
                Spacer()
                if composeFileURL != nil {
                    Button("Up") { runComposeUp() }
                    Button("Down") { runComposeDown() }
                }
            }
            .padding()
            if composeServices.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "Docker Compose",
                    message: "Open a docker-compose.yml file to view and manage services."
                )
            } else {
                List(composeServices) { service in
                    VStack(alignment: .leading) {
                        Text(service.name).font(.appBody)
                        if let image = service.image {
                            Text(image).font(.appCaption).foregroundStyle(.secondary)
                        }
                    }
                }
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

    private func statusDot(_ state: String) -> some View {
        Circle()
            .fill(state == "running" ? Color.statusGreen : Color.statusGray)
            .frame(width: 8, height: 8)
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
                        LabeledContent("Status", value: detail.state.status ?? "—")
                        LabeledContent("Running", value: detail.state.running == true ? "Yes" : "No")
                        LabeledContent("Started", value: detail.state.startedAt ?? "—")
                        LabeledContent("Finished", value: detail.state.finishedAt ?? "—")
                        if let config = detail.config {
                            LabeledContent("Image", value: config.image ?? "—")
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
