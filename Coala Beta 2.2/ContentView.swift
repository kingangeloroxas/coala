import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        currentScreenView
            .animation(.default, value: appState.currentScreen)
    }

    @ViewBuilder
    private var currentScreenView: some View {
        switch appState.currentScreen {
        case .landing:
            LandingView()

        case .onboarding:
            OnboardingView()

        case .activity:
            ActivitySelectionView()

        case .groupSize:
            GroupSizeSelectionView()             // keep your existing implementation

        case .matching:
            MatchingView()              // << IMPORTANT: zero-arg call

        case .chat:
            ChatView()

        case .profile:
            ProfileView()
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(AppState())
}
#endif

