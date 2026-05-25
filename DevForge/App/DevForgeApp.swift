import SwiftUI

@main
struct DevForgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var database = AppDatabase.shared
    @State private var showGlobalSearch = false
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @AppStorage("colorScheme") private var colorScheme = "auto"
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    var body: some Scene {
        WindowGroup {
            MainWindow(
                hasLaunchedBefore: $hasLaunchedBefore,
                showGlobalSearch: $showGlobalSearch,
                database: database
            )
            .frame(minWidth: 1000, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About DevForge") {
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandMenu("Navigate") {
                Button("Global Search") {
                    showGlobalSearch = true
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
        Settings {
            PreferencesView()
        }
        MenuBarExtraScene()
    }
}

struct MainWindow: View {
    @Binding var hasLaunchedBefore: Bool
    @Binding var showGlobalSearch: Bool
    let database: AppDatabase
    @AppStorage("colorScheme") private var colorScheme = "auto"

    var body: some View {
        Group {
            if !hasLaunchedBefore {
                OnboardingView()
            } else {
                ContentView()
                    .environment(\.database, database)
                    .sheet(isPresented: $showGlobalSearch) {
                        GlobalSearchView()
                    }
            }
        }
        .preferredColorScheme(colorScheme == "auto" ? nil : (colorScheme == "dark" ? ColorScheme.dark : ColorScheme.light))
    }
}

struct MenuBarExtraScene: Scene {
    @State private var runningCount = 0
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    var body: some Scene {
        MenuBarExtra("DevForge", systemImage: "terminal.fill", isInserted: $showMenuBarExtra) {
            VStack {
                Text("Running: \(runningCount)")
                    .font(.caption)
                Divider()
                Button("Show DevForge") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut("d", modifiers: [.command, .option])
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}
