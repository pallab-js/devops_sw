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
            VStack(alignment: .leading) {
                Text(file.name).font(.appBody)
                Text(file.projectPath).font(.appCaption).foregroundStyle(.secondary)
            }
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
                Text(file.name).font(.appHeadline)
                Spacer()
                Button("Import .env") { showImportPicker = true }
                Button("Export") { exportFile(file: file) }
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

    var body: some View {
        HStack {
            Text(variable.key).font(.appMonospaceSmall)
                .frame(width: 120, alignment: .leading)
            if showValue {
                Text(variable.value).font(.appMonospaceSmall)
            } else if variable.isSecret {
                Text("••••••••").foregroundStyle(.secondary)
            } else {
                Text(variable.value).font(.appMonospaceSmall)
            }
            Spacer()
            if variable.isSecret {
                Button(action: { showValue.toggle() }) {
                    Image(systemName: showValue ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
            }
            Button(action: onToggleSecret) {
                Image(systemName: variable.isSecret ? "lock.fill" : "lock.open")
            }
            .buttonStyle(.plain)
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
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
