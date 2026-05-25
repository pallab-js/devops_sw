import SwiftUI

struct EnvVaultView: View {
    @State private var envFiles: [EnvFile] = []
    @State private var selectedFile: EnvFile?
    @State private var variables: [EnvVariable] = []
    @State private var showNewFileSheet = false
    @State private var showImportPicker = false
    @State private var error: ErrorMessage?

    var body: some View {
        HSplitView {
            fileList
                .frame(minWidth: 200)
            if let selectedFile {
                variableList(file: selectedFile)
            } else {
                EmptyStateView(
                    icon: "lock.shield.fill",
                    title: "No Env File Selected",
                    message: "Select or create an environment file."
                )
            }
        }
        .task { await loadEnvFiles() }
        .sheet(isPresented: $showNewFileSheet) {
            NewEnvFileSheet { name, path in
                Task { await createFile(name: name, path: path) }
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.plainText, .text]
        ) { result in
            guard case .success(let url) = result,
                  let file = selectedFile else { return }
            Task { await importEnvFile(url: url, file: file) }
        }
        .alert(item: $error) { err in
            Alert(title: Text("Error"), message: Text(err.message))
        }
    }

    private var fileList: some View {
        List(envFiles, selection: $selectedFile) { file in
            HStack(spacing: Spacing.xs) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name).font(.appBody.bold())
                    Text(file.projectPath).font(.appCaption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(.vertical, 4)
            .tag(file)
        }
        .listStyle(.inset)
        .toolbar {
            ToolbarItem {
                Button(action: { showNewFileSheet = true }) {
                    Label("New", systemImage: "plus")
                }
            }
        }
    }

    private func variableList(file: EnvFile) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(file.name).font(.appTitle3.bold())
                    Text(file.projectPath).font(.appCaption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    ActionButton(title: "Import .env", icon: "square.and.arrow.down", color: .purple) {
                        showImportPicker = true
                    }
                    ActionButton(title: "Export", icon: "square.and.arrow.up", color: .blue) {
                        exportFile(file: file)
                    }
                }
            }
            .padding()
            Divider()
            List {
                ForEach(variables) { variable in
                    VariableRowView(
                        variable: variable,
                        onToggleSecret: { Task { await toggleSecret(variable) } },
                        onDelete: { Task { await deleteVariable(variable) } }
                    )
                }
            }
            .listStyle(.inset)
            .task(id: file.id) { await loadVariables(for: file.id) }
        }
    }

    private func loadEnvFiles() async {
        do {
            envFiles = try await EnvVaultService.shared.loadEnvFiles()
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func loadVariables(for fileId: String) async {
        do {
            variables = try await EnvVaultService.shared.loadVariables(for: fileId)
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func createFile(name: String, path: String) async {
        do {
            _ = try await EnvVaultService.shared.createEnvFile(name: name, projectPath: path)
            await loadEnvFiles()
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func importEnvFile(url: URL, file: EnvFile) async {
        do {
            _ = try await EnvVaultService.shared.importFromFile(url: url, envFileId: file.id)
            await loadVariables(for: file.id)
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func exportFile(file: EnvFile) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(file.name).env"
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            Task {
                do {
                    let content = try await EnvVaultService.shared.exportToEnvFormat(variables: variables)
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch { await MainActor.run { self.error = ErrorMessage(message: error.localizedDescription) } }
            }
        }
    }

    private func toggleSecret(_ variable: EnvVariable) async {
        var updated = variable
        updated.isSecret.toggle()
        do {
            try await EnvVaultService.shared.saveVariable(updated)
            await loadVariables(for: variable.envFileId)
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func deleteVariable(_ variable: EnvVariable) async {
        do {
            try await EnvVaultService.shared.deleteVariable(variable)
            await loadVariables(for: variable.envFileId)
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }
}

struct VariableRowView: View {
    let variable: EnvVariable
    let onToggleSecret: () -> Void
    let onDelete: () -> Void
    @State private var showValue = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text(variable.key)
                    .font(.appMonospaceSmall.bold())
            }
            .frame(width: 160, alignment: .leading)
            
            Group {
                if showValue || !variable.isSecret {
                    Text(variable.value)
                        .font(.appMonospaceSmall)
                        .foregroundStyle(.primary)
                } else {
                    Text("••••••••")
                        .font(.appMonospaceSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.appSecondaryBackground.opacity(0.5))
            .cornerRadius(4)
            
            Spacer()
            
            HStack(spacing: 8) {
                if variable.isSecret {
                    IconButton(icon: showValue ? "eye.slash" : "eye", color: .secondary) {
                        showValue.toggle()
                    }
                }
                IconButton(icon: variable.isSecret ? "lock.fill" : "lock.open", color: variable.isSecret ? .purple : .secondary, action: onToggleSecret)
                IconButton(icon: "trash", color: .red, action: onDelete)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .padding(.horizontal, 10)
        .background(isHovered ? Color.appSecondaryBackground.opacity(0.3) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct IconButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(color.opacity(isHovered ? 1.0 : 0.65))
                .frame(width: 24, height: 24)
                .background(isHovered ? color.opacity(0.12) : Color.clear)
                .cornerRadius(4)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct NewEnvFileSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String) -> Void
    @State private var name = ""
    @State private var projectPath = ""

    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("New Environment File").font(.appHeadline)
            Form {
                TextField("Name", text: $name)
                TextField("Project Path", text: $projectPath)
            }
            .formStyle(.grouped)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    onSave(name, projectPath)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 200)
    }
}
