import Foundation

struct User: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var age: Int
    var mbti: String
    var vibe: String
    var ethnicity: String
    var religion: String
    var attendanceRating: Double
    var attendance: [String]
    var badges: [String]
    var photoName: String?
    var activity: String?      // temporary for matching
    var city: String?          // stored user city (optional)

    init(
        id: UUID = UUID(),
        name: String,
        age: Int,
        mbti: String,
        vibe: String,
        ethnicity: String,
        religion: String,
        city: String? = nil,
        badges: [String],
        attendanceRating: Double,
        attendance: [String],
        photoName: String? = nil,
        activity: String? = nil
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.mbti = mbti
        self.vibe = vibe
        self.ethnicity = ethnicity
        self.religion = religion
        self.city = city
        self.badges = badges
        self.attendanceRating = attendanceRating
        self.attendance = attendance
        self.photoName = photoName
        self.activity = activity
    }
}

