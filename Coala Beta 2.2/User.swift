import Foundation

struct User: Identifiable, Hashable, Codable {
    let id: UUID
    // --- Permanent identity fields (not expected to change often) ---
    var name: String
    var age: Int
    var mbti: String
    var vibe: String
    var email: String?        // account email (optional until sign-up)
    var phone: String?        // account phone for OTP (optional until sign-up)
    var ethnicity: String
    var religion: String
    /// Current city and state; adjustable by the user over time.
    var city: String?          // optional so you can start with no city
    var state: String?         // optional so you can start with no state
    var gender: String         // "Male"/"Female" or "" during onboarding
    // --- Profile traits (editable) ---
    var senseOfHumor: String          // e.g., "dry / witty", "goofy"
    var conversationDepth: String     // e.g., "small talk", "deep talk"
    var leadership: String            // e.g., "leader", "wingman"
    var spontaneity: String           // e.g., "planner", "spontaneous"
    var socialEnergy: String          // e.g., "introvert", "ambivert", "extrovert"
    var alcoholPreference: String     // e.g., "never", "social", "often"
    var smokingPreference: String     // e.g., "no", "sometimes", "yes"
    var drugsPreference: String       // e.g., "no", "weed", "open"
    var badges: [String]
    var attendanceRating: Double
    var attendance: [String]
    var photoName: String?
    // --- Temporary, used during the matching flow ---
    /// The activity the user picked before matching (kept optional so they can land with none).
    var activity: String?
    /// Group size the user selected prior to matching (nil when unset).
    var selectedGroupSize: Int?

    init(
        id: UUID = UUID(),
        name: String,
        age: Int,
        mbti: String,
        vibe: String,
        email: String? = nil,
        phone: String? = nil,
        ethnicity: String,
        religion: String,
        city: String? = nil,
        state: String? = nil,
        gender: String = "",
        senseOfHumor: String = "",
        conversationDepth: String = "",
        leadership: String = "",
        spontaneity: String = "",
        socialEnergy: String = "",
        alcoholPreference: String = "",
        smokingPreference: String = "",
        drugsPreference: String = "",
        badges: [String],
        attendanceRating: Double,
        attendance: [String],
        photoName: String? = nil,
        activity: String? = nil,
        selectedGroupSize: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.mbti = mbti
        self.vibe = vibe
        self.email = email
        self.phone = phone
        self.ethnicity = ethnicity
        self.religion = religion
        self.city = city
        self.state = state
        self.gender = gender
        self.senseOfHumor = senseOfHumor
        self.conversationDepth = conversationDepth
        self.leadership = leadership
        self.spontaneity = spontaneity
        self.socialEnergy = socialEnergy
        self.alcoholPreference = alcoholPreference
        self.smokingPreference = smokingPreference
        self.drugsPreference = drugsPreference
        self.badges = badges
        self.attendanceRating = attendanceRating
        self.attendance = attendance
        self.photoName = photoName
        self.activity = activity
        self.selectedGroupSize = selectedGroupSize
    }
}
