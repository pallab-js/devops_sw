import SwiftUI

struct GitWorkspaceView: View {
    @State private var repositories: [GitRepository] = []
    @State private var selectedRepo: GitRepository?
    @State private var statusFiles: [GitFileStatus] = []
    @State private var commits: [GitCommit] = []
    @State private var branches: [(name: String, isCurrent: Bool)] = []
    @State private var stashes: [(index: Int, message: String)] = []
    @State private var selectedTab = 0
    @State private var commitMessage = ""
    @State private var showAddRepo = false
    @State private var error: ErrorMessage?

    var body: some View {
        HSplitView {
            repoList
                .frame(minWidth: 200)
            if let repo = selectedRepo {
                repoDetail(repo: repo)
            } else {
                EmptyStateView(
                    icon: "arrow.triangle.branch",
                    title: "No Repository Selected",
                    message: "Add a Git repository to get started."
                )
            }
        }
        .sheet(isPresented: $showAddRepo) {
            AddRepoSheet { path in
                Task { await addRepo(path: path) }
            }
        }
        .alert(item: $error) { err in
            Alert(title: Text("Error"), message: Text(err.message))
        }
    }

    private var repoList: some View {
        List(repositories, selection: $selectedRepo) { repo in
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text(repo.name).font(.appBody)
                    if let branch = repo.currentBranch {
                        Text(branch).font(.appCaption)
                            .padding(.horizontal, 4)
                            .background(Color.appSecondaryBackground)
                            .cornerRadius(4)
                    }
                    if repo.isDirty {
                        Text("●").foregroundStyle(Color.statusYellow)
                    }
                }
                Text(repo.localPath).font(.appCaption).foregroundStyle(.secondary)
            }
            .tag(repo)
        }
        .listStyle(.inset)
        .toolbar {
            ToolbarItem { Button(action: { showAddRepo = true }) { Label("Add", systemImage: "plus") } }
        }
    }

    private func repoDetail(repo: GitRepository) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(repo.name).font(.appHeadline)
                Spacer()
                Button("Pull") { Task { await pullRepo(repo) } }
                Button("Push") { Task { await pushRepo(repo) } }
            }
            .padding()
            Picker("", selection: $selectedTab) {
                Text("Status").tag(0)
                Text("Log").tag(1)
                Text("Branches").tag(2)
                Text("Stashes").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            TabView(selection: $selectedTab) {
                statusView(repo: repo).tag(0)
                logView(repo: repo).tag(1)
                branchesView(repo: repo).tag(2)
                stashesView(repo: repo).tag(3)
            }
            .tabViewStyle(.automatic)
        }
        .task(id: repo.id) { await loadRepoData(repo: repo) }
    }

    private func statusView(repo: GitRepository) -> some View {
        VStack {
            List {
                ForEach(statusFiles.filter { $0.statusCode != .untracked }) { file in
                    HStack {
                        Text(file.statusCode.label)
                            .font(.appCaption.bold())
                            .foregroundStyle(statusColor(file.statusCode))
                            .frame(width: 70)
                        Text(file.path).font(.appMonospaceSmall)
                    }
                }
            }
            Divider()
            VStack(spacing: Spacing.xs) {
                TextField("Commit message", text: $commitMessage)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Stage All") {
                        Task {
                            let files = statusFiles.map { $0.path }
                            try? await GitService.shared.stage(files: files, repoPath: repo.localPath)
                            await loadRepoData(repo: repo)
                        }
                    }
                    Spacer()
                    Button("Commit") {
                        Task {
                            try? await GitService.shared.commit(repoPath: repo.localPath, message: commitMessage)
                            commitMessage = ""
                            await loadRepoData(repo: repo)
                        }
                    }
                    .disabled(commitMessage.trimmed.isEmpty)
                }
            }
            .padding()
        }
    }

    private func logView(repo: GitRepository) -> some View {
        List(commits) { commit in
            HStack {
                Text(commit.shortSha).font(.appMonospaceSmall)
                VStack(alignment: .leading) {
                    Text(commit.message).font(.appBody).lineLimit(1)
                    Text(commit.author).font(.appCaption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(commit.date.formatted).font(.appCaption).foregroundStyle(.secondary)
            }
            .onTapGesture {
                // show diff sheet
            }
        }
    }

    private func branchesView(repo: GitRepository) -> some View {
        List(branches, id: \.name) { branch in
            HStack {
                Text(branch.name).font(.appBody)
                if branch.isCurrent { Text("current").font(.appCaption) }
                Spacer()
                Button("Checkout") {
                    Task {
                        try? await GitService.shared.checkout(branch: branch.name, repoPath: repo.localPath)
                        await loadRepoData(repo: repo)
                    }
                }
                .disabled(branch.isCurrent)
            }
        }
    }

    private func stashesView(repo: GitRepository) -> some View {
        List(stashes, id: \.index) { stash in
            HStack {
                Text("stash@{\(stash.index)}").font(.appMonospaceSmall)
                Text(stash.message).font(.appBody)
                Spacer()
                Button("Apply") {
                    Task {
                        try? await GitService.shared.stashPop(repoPath: repo.localPath)
                        await loadRepoData(repo: repo)
                    }
                }
                Button("Drop") {
                    Task {
                        try? await GitService.shared.stashDrop(repoPath: repo.localPath, index: stash.index)
                        await loadRepoData(repo: repo)
                    }
                }
            }
        }
    }

    private func loadRepoData(repo: GitRepository) async {
        do {
            let status = try await GitService.shared.getStatus(repoPath: repo.localPath)
            statusFiles = status.files
            commits = try await GitService.shared.getLog(repoPath: repo.localPath)
            branches = try await GitService.shared.getBranches(repoPath: repo.localPath)
            stashes = try await GitService.shared.stashList(repoPath: repo.localPath)
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func addRepo(path: String) async {
        guard FileManager.default.fileExists(atPath: path + "/.git") else {
            error = ErrorMessage(message: "Not a Git repository")
            return
        }
        let name = URL(fileURLWithPath: path).lastPathComponent
        let repo = GitRepository(localPath: path, name: name)
        do {
            let status = try await GitService.shared.getStatus(repoPath: path)
            let allCommits = try await GitService.shared.getLog(repoPath: path, limit: 1)
            try await AppDatabase.shared.write { db in
                try repo.insert(db)
            }
            await loadRepositories()
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func pullRepo(_ repo: GitRepository) async {
        do {
            let output = try await GitService.shared.pull(repoPath: repo.localPath)
            await loadRepoData(repo: repo)
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func pushRepo(_ repo: GitRepository) async {
        do {
            let output = try await GitService.shared.push(repoPath: repo.localPath)
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func loadRepositories() async {
        do {
            repositories = try await AppDatabase.shared.read { db in
                try GitRepository.fetchAll(db)
            }
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func statusColor(_ type: GitStatusType) -> Color {
        switch type {
        case .modified: .statusYellow
        case .added: .statusGreen
        case .deleted: .statusRed
        case .untracked: .gray
        case .renamed: .blue
        }
    }
}

struct AddRepoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String) -> Void
    @State private var path = ""

    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("Add Repository").font(.appHeadline)
            HStack {
                TextField("Repository path", text: $path)
                Button("Browse") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.begin { resp in
                        if resp == .OK, let url = panel.url { path = url.path }
                    }
                }
            }
            .padding()
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") { onAdd(path); dismiss() }
                    .disabled(path.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 150)
    }
}
