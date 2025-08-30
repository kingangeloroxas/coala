import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        SwiftUI.Group {
            if appState.isBootstrapping {
                SplashView(onStart: {})
            } else {
                currentScreenView
            }
        }
        .onAppear {
            if appState.isBootstrapping {
                appState.startAuthObserver()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.currentScreen)
    }

    // MARK: - Router
    @ViewBuilder
    private var currentScreenView: some View {
        switch appState.currentScreen {
        case .landing:
            SplashView(onStart: {})

        case .splash:
            SplashView(onStart: {})

        case .signup:
            SignUpView()

        case .login:
            LoginView()

        case .intro:
            OnboardingView()

        case .onboarding:
            OnboardingView()

        case .traits:
            TraitsView()

        case .activity:
            ActivitySelectionView()

        case .groupSize:
            GroupSizeSelectionView()

        case .matching:
            HubView()

        case .chat:
            ChatView()

        case .profile:
            ProfileView()

        case .home:
            HomeView()

        case .hub:
            HubView()
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(AppState())
}
#endif

// TEMP stubs so router compiles if these files aren't in the target yet.
// Remove these once your real views exist in the build target.
struct SignUpView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.key.fill")
                .font(.largeTitle)
                .foregroundStyle(.blue)
            Text("Sign Up")
                .font(.title3.weight(.semibold))
            Text("(Placeholder view – replace with your real SignUpView)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct TraitsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.largeTitle)
                .foregroundStyle(.blue)
            Text("Traits Setup")
                .font(.title3.weight(.semibold))
            Text("(Placeholder view – replace with your real TraitsView)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
