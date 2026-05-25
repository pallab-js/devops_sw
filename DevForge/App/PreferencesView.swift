import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            AppearanceSettingsView()
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            ShortcutsSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            DataSettingsView()
                .tabItem { Label("Data", systemImage: "externaldrive") }
        }
        .frame(width: 500, height: 350)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        loginItemError = nil
                    } catch {
                        loginItemError = error.localizedDescription
                        launchAtLogin = !newValue
                    }
                }
            Toggle("Show menu bar extra", isOn: $showMenuBarExtra)
            if let err = loginItemError {
                Text(err)
                    .font(.appCaption)
                    .foregroundStyle(Color.statusRed)
            }
        }
        .formStyle(.grouped)
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("colorScheme") private var colorScheme = "auto"

    var body: some View {
        Form {
            Picker("Color Scheme", selection: $colorScheme) {
                Text("Auto").tag("auto")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
        }
        .formStyle(.grouped)
    }
}

struct ShortcutsSettingsView: View {
    var body: some View {
        List {
            LabeledContent("Global Search", value: "Cmd+K")
            LabeledContent("New Process", value: "Cmd+N")
            LabeledContent("Refresh", value: "Cmd+R")
            LabeledContent("Preferences", value: "Cmd+,")
        }
        .formStyle(.grouped)
    }
}

struct DataSettingsView: View {
    @State private var dbSize = ""
    @State private var isExporting = false

    var body: some View {
        Form {
            LabeledContent("Database Size", value: dbSize)
            HStack {
                Button("Export All Data") {
                    exportData()
                }
                .disabled(isExporting)
                Spacer()
                Button("Clear History", role: .destructive) {
                    Task {
                        try? await AppDatabase.shared.write { db in
                            try TaskRun.deleteAll(db)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task { await loadDBSize() }
    }

    private func loadDBSize() async {
        let url = AppDatabase.databaseURL()
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attrs?[.size] as? Int64 {
            dbSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        } else {
            dbSize = "\u{2014}"
        }
    }

    private func exportData() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "devforge-export.json"
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            isExporting = true
            Task {
                do {
                    try await DataExporter.shared.exportAll(to: url)
                    await MainActor.run { isExporting = false }
                } catch {
                    await MainActor.run { isExporting = false }
                }
            }
        }
    }
}
