import SwiftUI

struct LandingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            // Big logo that fills safely but preserves aspect
            Image("coala_logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
                .contentShape(Rectangle()) // large hit area
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    appState.currentScreen = .onboarding   // <- navigate here
                }
        }
    }
}

