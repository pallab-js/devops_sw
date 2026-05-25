import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: onboardingIcon)
                .font(.system(size: 80))
                .foregroundStyle(Color.appAccent)
            Text(onboardingTitle)
                .font(.appTitle)
                .multilineTextAlignment(.center)
            Text(onboardingMessage)
                .font(.appBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .padding(.horizontal)
            Spacer()
            HStack(spacing: Spacing.sm) {
                ForEach(pages.indices, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage ? Color.appAccent : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            HStack {
                Button("Skip") {
                    hasLaunchedBefore = true
                }
                .keyboardShortcut(.escape)
                Spacer()
                Button(currentPage < pages.count - 1 ? "Next" : "Get Started") {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        hasLaunchedBefore = true
                    }
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 520, height: 420)
    }

    private let pages = [
        ("terminal.fill", "Welcome to DevForge", "Your local DevOps command center. Manage processes, Docker, Git, SSH, and more, all offline with zero cloud dependency."),
        ("shippingbox.fill", "Tool Detection", "DevForge auto-detects Docker, Git, and developer tools on your system. Features adapt based on what's available."),
        ("keyboard.fill", "Keyboard Shortcuts", "Cmd+K: Global Search • Cmd+N: New Process • Cmd+,: Preferences"),
    ]

    private var onboardingIcon: String { pages[currentPage].0 }
    private var onboardingTitle: String { pages[currentPage].1 }
    private var onboardingMessage: String { pages[currentPage].2 }
}
