import SwiftUI

struct NewProcessSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (ProcessRecord) -> Void

    @State private var name = ""
    @State private var command = ""
    @State private var workingDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var envKey = ""
    @State private var envValue = ""
    @State private var envVars: [String: String] = [:]

    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("New Process")
                .font(.appHeadline)
            Form {
                TextField("Name", text: $name)
                TextField("Command", text: $command)
                HStack {
                    TextField("Working Directory", text: $workingDirectory)
                    Button("Browse") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.begin { resp in
                            if resp == .OK, let url = panel.url {
                                workingDirectory = url.path
                            }
                        }
                    }
                }
                Section("Environment Variables") {
                    HStack {
                        TextField("Key", text: $envKey)
                        TextField("Value", text: $envValue)
                        Button("Add") {
                            guard !envKey.isEmpty else { return }
                            envVars[envKey] = envValue
                            envKey = ""
                            envValue = ""
                        }
                    }
                    List(Array(envVars.keys), id: \.self) { key in
                        HStack {
                            Text(key).font(.appMonospaceSmall)
                            Text("=").foregroundStyle(.secondary)
                            Text(envVars[key] ?? "").font(.appMonospaceSmall)
                            Spacer()
                            Button {
                                envVars.removeValue(forKey: key)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    let record = ProcessRecord(
                        name: name.trimmed,
                        command: command.trimmed,
                        workingDirectory: workingDirectory.trimmed,
                        environmentVariables: envVars
                    )
                    onSave(record)
                    dismiss()
                }
                .disabled(name.trimmed.isEmpty || command.trimmed.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 450)
    }
}
