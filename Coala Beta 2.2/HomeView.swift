import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Welcome, \(appState.currentUser.name.isEmpty ? "Guest" : appState.currentUser.name)")
                    .font(.title)
                    .padding(.top)

                Button("Go to Profile") {
                    appState.currentScreen = .profile
                }
                .buttonStyle(.borderedProminent)

                Button("Go to Activity Selection") {
                    appState.currentScreen = .activity
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .navigationTitle("Home")
        }
    }
}

