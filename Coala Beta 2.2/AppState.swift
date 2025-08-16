import SwiftUI

final class AppState: ObservableObject {
    // MARK: - Routing

    enum Screen {
        case landing
        case onboarding
        case activity
        case groupSize
        case matching
        case chat
        case profile
    }

    @Published var currentScreen: Screen = .landing

    // MARK: - User / Matching State

    // Concrete fallback user matching User.init(...) exactly
    private static let defaultUser = User(
        name: "You",
        age: 25,
        mbti: "",
        vibe: "Chill",
        ethnicity: "",
        religion: "",
        city: nil,
        badges: [],
        attendanceRating: 5.0,
        attendance: [],
        photoName: nil,
        activity: nil
    )

    @Published var currentUser: User = SampleData.users.first ?? AppState.defaultUser
    @Published var matchedUsers: [User] = []

    // Selections
    @Published var selectedActivity: String?
    @Published var selectedGroupSize: Int?

    // City (set by Onboarding)
    @Published var userCity: String = ""

    // MARK: - Navigation

    func goBack() {
        switch currentScreen {
        case .onboarding: currentScreen = .landing
        case .activity:   currentScreen = .onboarding
        case .groupSize:  currentScreen = .activity
        case .matching:   currentScreen = .groupSize
        case .chat:       currentScreen = .matching
        case .profile:    currentScreen = .chat
        case .landing:    break
        }
    }

    // MARK: - Compatibility shims

    func goTo(_ screen: Screen) { currentScreen = screen }
    func goNextFromOnboarding() { currentScreen = .activity }
    var allUsers: [User] { SampleData.users }
}

