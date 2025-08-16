import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            AppTopBar(title: "profile", onBack: { appState.goBack() })

            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(appState.currentUser.name.isEmpty ? "You" : appState.currentUser.name)
                    .font(.title2).bold()

                HStack(spacing: 12) {
                    if !appState.currentUser.mbti.isEmpty {
                        Label(appState.currentUser.mbti, systemImage: "person.text.rectangle")
                    }
                    Label("Attendance \(appState.currentUser.attendanceRating)", systemImage: "checkmark.seal")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            // Location
            VStack(alignment: .leading, spacing: 8) {
                if !appState.userCity.isEmpty {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                        Text(appState.userCity)
                    }
                } else {
                    Text("No city set yet").foregroundStyle(.secondary)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            // Edit button
            Button {
                // Navigate back to onboarding to edit details/location
                appState.currentScreen = .onboarding
            } label: {
                Text("Edit Location")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
    }
}

