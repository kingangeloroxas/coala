import SwiftUI

struct LandingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        // Stay on splash; only move when user taps a button.
        SplashView(onStart: {
            // “Set Up” should take the user to Sign Up, not Onboarding.
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            appState.goToSignup()
        })
        .environmentObject(appState)
    }
}
