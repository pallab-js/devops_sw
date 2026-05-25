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
            Text(onboardingMessage)
                .font(.appBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            Spacer()
            HStack {
                Button("Skip") {
                    hasLaunchedBefore = true
                }
                Spacer()
                if currentPage < pages.count - 1 {
                    Button("Next") { currentPage += 1 }
                } else {
                    Button("Get Started") {
                        hasLaunchedBefore = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }

    private let pages = [
        ("terminal.fill", "Welcome to DevForge", "Your local DevOps command center. Manage processes, Docker, Git, and more — all offline."),
        ("shippingbox.fill", "Tool Detection", ""),
        ("keyboard.fill", "Keyboard Shortcuts", "Cmd+K: Global Search • Cmd+N: New Process • Cmd+,: Preferences"),
    ]

    private var onboardingIcon: String { pages[currentPage].0 }
    private var onboardingTitle: String { pages[currentPage].1 }
    private var onboardingMessage: String { pages[currentPage].2 }
}
