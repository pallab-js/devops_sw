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
                .frame(minWidth: 220)
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
        .task { await loadRepositories() }
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
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                    
                    Text(repo.name)
                        .font(.appBody.bold())
                    
                    Spacer()
                    
                    if let branch = repo.currentBranch {
                        Text(branch)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appSecondaryBackground)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.appSeparator, lineWidth: 1)
                            )
                    }
                    
                    if repo.isDirty {
                        Circle()
                            .fill(Color.statusYellow)
                            .frame(width: 6, height: 6)
                    }
                }
                
                Text(repo.localPath)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, Spacing.xxs)
            .tag(repo)
        }
        .listStyle(.inset)
        .toolbar {
            ToolbarItem {
                Button(action: { showAddRepo = true }) {
                    Label("Add", systemImage: "plus")
                }
            }
        }
    }

    private func repoDetail(repo: GitRepository) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(repo.name)
                        .font(.appTitle3.bold())
                    Text(repo.localPath)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    ActionButton(title: "Pull", icon: "arrow.down.circle", color: .appAccent) {
                        Task { await pullRepo(repo) }
                    }
                    ActionButton(title: "Push", icon: "arrow.up.circle", color: .statusGreen) {
                        Task { await pushRepo(repo) }
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

            Picker("", selection: $selectedTab) {
                Text("Status").tag(0)
                Text("Log").tag(1)
                Text("Branches").tag(2)
                Text("Stashes").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()
            
            TabView(selection: $selectedTab) {
                statusView(repo: repo).tag(0)
                logView(repo: repo).tag(1)
                branchesView(repo: repo).tag(2)
                stashesView(repo: repo).tag(3)
            }
            .tabViewStyle(.automatic)
            .padding(.horizontal)
        }
        .task(id: repo.id) { await loadRepoData(repo: repo) }
    }

    private func statusView(repo: GitRepository) -> some View {
        VStack(spacing: 0) {
            if statusFiles.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle.fill",
                    title: "Working Directory Clean",
                    message: "No modifications, additions, or deletions found."
                )
                .frame(maxHeight: .infinity)
            } else {
                List(statusFiles) { file in
                    HStack(spacing: Spacing.sm) {
                        gitStatusBadge(file.statusCode)
                        
                        Text(file.path)
                            .font(.appMonospaceSmall)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .padding(.vertical, Spacing.xxs)
                    .padding(.horizontal, Spacing.xs)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.06), lineWidth: 1)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            
            Divider()
            
            VStack(spacing: Spacing.sm) {
                TextField("Commit message", text: $commitMessage)
                    .textFieldStyle(.roundedBorder)
                    .font(.appBody)
                
                HStack {
                    ActionButton(title: "Stage All", icon: "square.dashed.inset.filled", color: .appAccent) {
                        Task {
                            let files = statusFiles.map { $0.path }
                            try? await GitService.shared.stage(files: files, repoPath: repo.localPath)
                            await loadRepoData(repo: repo)
                        }
                    }
                    .disabled(statusFiles.isEmpty)
                    
                    Spacer()
                    
                    ActionButton(title: "Commit", icon: "checkmark.circle", color: .statusGreen) {
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
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.vertical, Spacing.sm)
        }
    }

    private func logView(repo: GitRepository) -> some View {
        List(commits) { commit in
            HStack(alignment: .center, spacing: Spacing.sm) {
                initialsBadge(author: commit.author)
                
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack {
                        Text(commit.message)
                            .font(.appBody.bold())
                            .lineLimit(1)
                        Spacer()
                        Text(commit.shortSha)
                            .font(.appMonospaceSmall.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appSecondaryBackground)
                            .cornerRadius(4)
                    }
                    
                    HStack {
                        Text(commit.author)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(commit.date.formatted)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
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
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func branchesView(repo: GitRepository) -> some View {
        List(branches, id: \.name) { branch in
            HStack {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(branch.isCurrent ? Color.statusGreen : .secondary)
                    Text(branch.name)
                        .font(branch.isCurrent ? .appBody.bold() : .appBody)
                }
                
                if branch.isCurrent {
                    Text("CURRENT")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.statusGreen.opacity(0.12))
                        .foregroundStyle(Color.statusGreen)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.statusGreen.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Spacer()
                
                ActionButton(title: "Checkout", icon: "arrow.right.circle", color: .appAccent) {
                    Task {
                        try? await GitService.shared.checkout(branch: branch.name, repoPath: repo.localPath)
                        await loadRepoData(repo: repo)
                    }
                }
                .disabled(branch.isCurrent)
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

    @ViewBuilder
    private func stashesView(repo: GitRepository) -> some View {
        if stashes.isEmpty {
            EmptyStateView(
                icon: "tray",
                title: "No Stashes Found",
                message: "Saved changes will appear here."
            )
        } else {
            List(stashes, id: \.index) { stash in
                HStack(spacing: Spacing.sm) {
                    Text("stash@{\(stash.index)}")
                        .font(.appMonospaceSmall.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.appSecondaryBackground)
                        .cornerRadius(4)
                    
                    Text(stash.message)
                        .font(.appBody)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        ActionButton(title: "Apply", icon: "tray.and.arrow.down", color: .statusGreen) {
                            Task {
                                try? await GitService.shared.stashPop(repoPath: repo.localPath)
                                await loadRepoData(repo: repo)
                            }
                        }
                        ActionButton(title: "Drop", icon: "trash", color: .statusRed) {
                            Task {
                                try? await GitService.shared.stashDrop(repoPath: repo.localPath, index: stash.index)
                                await loadRepoData(repo: repo)
                            }
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
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
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
            try await AppDatabase.shared.write { db in
                try repo.insert(db)
            }
            await loadRepositories()
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func pullRepo(_ repo: GitRepository) async {
        do {
            _ = try await GitService.shared.pull(repoPath: repo.localPath)
            await loadRepoData(repo: repo)
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func pushRepo(_ repo: GitRepository) async {
        do {
            _ = try await GitService.shared.push(repoPath: repo.localPath)
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
        case .untracked: .statusGray
        case .renamed: .blue
        }
    }

    private func gitStatusBadge(_ type: GitStatusType) -> some View {
        let color = statusColor(type)
        return Text(type.label.uppercased())
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
            .frame(width: 75)
    }

    private func authorInitials(_ author: String) -> String {
        let parts = author.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1).uppercased() + parts[1].prefix(1).uppercased())
        }
        return String(author.prefix(2).uppercased())
    }

    private func initialsBadge(author: String) -> some View {
        Text(authorInitials(author))
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(Color.appAccent.opacity(0.8))
            .clipShape(Circle())
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
