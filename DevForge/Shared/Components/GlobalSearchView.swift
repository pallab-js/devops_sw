import SwiftUI
import GRDB

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search processes, env files, repos, hosts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.appTitle3)
                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            Divider()
            if searchResults.isEmpty && !searchText.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Results",
                    message: "No matches found for \"\(searchText)\"."
                )
            } else {
                List(searchResults) { result in
                    HStack {
                        Image(systemName: result.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading) {
                            Text(result.title).font(.appBody)
                            Text(result.subtitle).font(.appCaption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(result.category).font(.appCaption).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismiss()
                        // navigate to the relevant section
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 500, height: 400)
        .onChange(of: searchText) { _, newValue in
            guard !newValue.isEmpty else { searchResults = []; return }
            Task { await performSearch(newValue) }
        }
    }

    private func performSearch(_ query: String) async {
        isSearching = true
        defer { isSearching = false }

        var results: [SearchResult] = []
        do {
            let processes: [ProcessRecord] = try await AppDatabase.shared.read { db in
                try ProcessRecord.filter(Column("name").like("%\(query)%")).fetchAll(db)
            }
            results.append(contentsOf: processes.map {
                SearchResult(title: $0.name, subtitle: $0.command, icon: "terminal.fill", category: "Process")
            })

            let envFiles: [EnvFile] = try await AppDatabase.shared.read { db in
                try EnvFile.filter(Column("name").like("%\(query)%")).fetchAll(db)
            }
            results.append(contentsOf: envFiles.map {
                SearchResult(title: $0.name, subtitle: $0.projectPath, icon: "lock.shield.fill", category: "Env")
            })

            let repos: [GitRepository] = try await AppDatabase.shared.read { db in
                try GitRepository.filter(Column("name").like("%\(query)%")).fetchAll(db)
            }
            results.append(contentsOf: repos.map {
                SearchResult(title: $0.name, subtitle: $0.localPath, icon: "arrow.triangle.branch", category: "Git")
            })
        } catch {}
        searchResults = results
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let category: String
}
