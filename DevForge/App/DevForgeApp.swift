import SwiftUI

@main
struct DevForgeApp: App {
    @State private var database = AppDatabase.shared
    @State private var showGlobalSearch = false
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false

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

    var body: some View {
        if !hasLaunchedBefore {
            OnboardingView()
        } else {
            ContentView()
                .environment(\.database, database)
                .sheet(isPresented: $showGlobalSearch) {
                    GlobalSearchView()
                }
                .onAppear { setupKeyboardShortcuts() }
        }
    }

    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.characters == "k" {
                showGlobalSearch = true
                return nil
            }
            return event
        }
    }
}

struct MenuBarExtraScene: Scene {
    var body: some Scene {
        MenuBarExtra("DevForge", systemImage: "terminal.fill") {
            MenuBarExtraView()
        }
    }
}
