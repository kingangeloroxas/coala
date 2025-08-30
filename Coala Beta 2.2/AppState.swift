import SwiftUI
import FirebaseAuth
import FirebaseFirestore

final class AppState: ObservableObject {

    // MARK: - App Screens
    enum Screen: Hashable {
        case landing
        case splash
        case signup     // 👈 changed from signUp to signup
        case login     // 👈 NEW: email/password login screen
        case intro
        case onboarding
        case traits
        case activity
        case groupSize
        case matching
        case hub          // 👈 NEW main hub
        case home         // keep if used elsewhere
        case profile
        case chat
    }

    // MARK: - Routing
    @Published var currentScreen: Screen = .splash
    @Published var isBootstrapping: Bool = true
    private var stack: [Screen] = []

    func navigate(to next: Screen) {
        stack.append(currentScreen)
        currentScreen = next
    }
    func goBack() {
        guard let prev = stack.popLast() else { return }
        currentScreen = prev
    }

    // Convenience routes
    func goToIntro()      { navigate(to: .intro) }
    func goToSignup()     { navigate(to: .signup) }       // 👈 renamed from goToSignUp and updated
    func goToLogin()      { navigate(to: .login) }
    func goToOnboarding() { navigate(to: .onboarding) }
    func goToTraits()    { navigate(to: .traits) }
    func goToHub()        { navigate(to: .hub) }        // 👈 NEW
    func goToActivity()   { navigate(to: .activity) }
    func goToGroupSize()  { navigate(to: .groupSize) }
    func goToMatching()   { navigate(to: .matching) }
    func goToProfile()    { navigate(to: .profile) }
    func goToChat()       { navigate(to: .chat) }

    // MARK: - Onboarding / Matching state
    @Published var userCity: String = ""
    @Published var userState: String = ""
    // Auth (filled on SignUpView)
    @Published var authEmail: String = ""
    @Published var authPhone: String = ""
    // Auth session state
    @Published var isLoggedIn: Bool = false {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: "coala.isLoggedIn") }
    }
    
    init() {
        // restore simple session flag if you want auto-resume
        if UserDefaults.standard.bool(forKey: "coala.isLoggedIn") {
            isLoggedIn = true
        }
    }

    // Profile metrics
    @Published var activitiesMatchedCount: Int = 0
    @Published var activitiesCompletedCount: Int = 0
    @Published var topBranchCount: Int = 0

    // Onboarding “six traits” answers (human-readable labels as keys)
    @Published var traitAnswers: [String: String] = [:]

    @Published var selectedActivity: String? = nil
    @Published var selectedGroupSize: Int? = nil
    @Published var matchedUsers: [User] = []

    @Published var currentUser: User = User(
        id: UUID(),
        name: "",
        age: 18,
        mbti: "",
        vibe: "",
        ethnicity: "",
        religion: "",
        city: "",
        state: "",
        gender: "",
        badges: [],
        attendanceRating: 0.0,
        attendance: []
    )

    @Published var genderMode: GenderMode = .any
    @Published var weights: MatchingWeights = .default

    /// Merge a subset of onboarding fields into the working user
    func applyOnboardingPart(name: String,
                             age: Int,
                             gender: String,
                             city: String?,
                             state: String?) {
        var u = currentUser
        u.name   = name
        u.age    = age
        u.gender = gender
        u.city   = (city ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        u.state  = (state ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        currentUser = u
    }

    /// After successful Sign Up, go to the onboarding front page
    func goNextFromSignup() {
        navigate(to: .onboarding)
    }

    /// After the traits screen, send users to the new Hub
    func goNextFromOnboarding() {
        navigate(to: .traits)
    }

    var hasSeenIntro: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenIntro") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenIntro") }
    }

    // MARK: - Auth flow helpers
    /// Call after a successful sign up.
    func handleSignUpSuccess(email: String, phone: String) {
        authEmail = email
        authPhone = phone
        isLoggedIn = true
        // After account creation, send user to Login to sign in → prevents onboarding flash
        currentScreen = .login
    }

    /// Call after a successful log in.
    func handleLoginSuccess(email: String) {
        authEmail = email
        isLoggedIn = true
        // Decide between Hub vs Onboarding based on profile
        if let uid = Auth.auth().currentUser?.uid {
            routePostAuth(uid: uid)
        } else {
            // Fallback if auth state not yet reflected
            checkOnboardingCompletion()
        }
    }

    // MARK: - Auth bootstrap (centralized, no onboarding flicker)
    func startAuthObserver() {
        isBootstrapping = true
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if let user = user {
                self.routePostAuth(uid: user.uid)
            } else {
                // Unauthenticated → stay on Splash until user taps
                self.currentScreen = .splash
                self.isBootstrapping = false
            }
        }
    }

    func routePostAuth(uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { [weak self] snap, _ in
            guard let self = self else { return }
            let data = snap?.data() ?? [:]
            if self.isOnboardingComplete(data: data) {
                self.currentScreen = .hub
            } else {
                self.currentScreen = .onboarding
            }
            self.isBootstrapping = false
        }
    }

    private func isOnboardingComplete(data: [String: Any]) -> Bool {
        if let step = data["onboardingStep"] as? String,
           ["done", "complete"].contains(step.lowercased()) { return true }
        let required = ["name","gender","city","state","ethnicity","religion"]
        for k in required {
            if (data[k] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                return false
            }
        }
        if (data["age"] as? Int) == nil { return false }
        // Traits completeness (tolerant): at least 5 non-empty entries
        if let traits = data["traits"] as? [String: Any] {
            let filled = traits.values.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            return filled.count >= 5
        }
        return false
    }

    /// Wipe lightweight auth and return to landing.
    func signOut() {
        isLoggedIn = false
        authEmail = ""
        authPhone = ""
        stack.removeAll()
        currentScreen = .splash
    }


    // MARK: - Onboarding completion gate (Hub fast‑path)
    /// Reads the current user's document and routes to Hub or Onboarding accordingly.
    /// Call this on Splash/after Login to avoid showing onboarding to completed users.
    func checkOnboardingCompletion() {
        guard let uid = Auth.auth().currentUser?.uid else {
            // Not authenticated – remain on Splash until a button is pressed
            currentScreen = .splash
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { [weak self] snap, error in
            guard let self = self else { return }

            if let error = error {
                print("[AppState] Firestore read failed: \(error)")
                // Fall back to onboarding if we can’t decide
                self.goToOnboarding()
                return
            }

            guard let data = snap?.data() else {
                // No profile yet → start onboarding
                self.goToOnboarding()
                return
            }

            if self.isProfileComplete(data: data) {
                self.goToHub()
            } else {
                self.goToOnboarding()
            }
        }
    }

    /// Minimal completeness rules so we can skip onboarding for finished users.
    /// Adjust to your real schema as needed.
    private func isProfileComplete(data: [String: Any]) -> Bool {
        // Required top‑level fields
        let requiredStringKeys = ["name", "gender", "city", "state", "ethnicity", "religion"]
        for key in requiredStringKeys {
            if (data[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true { return false }
        }
        if (data["age"] as? Int) == nil { return false }

        // Traits block should contain the core answers we collect
        guard let traits = data["traits"] as? [String: Any] else { return false }
        let coreTraitKeys = [
            "Sense of humor",
            "Conversation level",
            "Leadership",
            "Spontaneity",
            "Social energy",
            "Alcohol",
            "Smoking",
            "Drugs"
        ]
        for key in coreTraitKeys {
            if (traits[key] as? String)?.isEmpty ?? true { return false }
        }
        return true
    }
}

// MARK: - Persisted Settings
private let kDistanceCutoffKey = "coala.distanceCutoffMiles.v1"
extension AppState {
    var distanceCutoffMiles: Double {
        get {
            let v = UserDefaults.standard.double(forKey: kDistanceCutoffKey)
            return v == 0 ? 10 : v
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kDistanceCutoffKey)
        }
    }
}
