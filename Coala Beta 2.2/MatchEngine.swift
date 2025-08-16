import Foundation

final class MatchEngine {
    func findMatches(for user: User, in pool: [User]) -> [User] {
        // Simple example: everyone except self
        pool.filter { $0.id != user.id }
    }

    // Test pool (kept minimal; matches current User initializer)
    static let testPool: [User] = [
        User(
            name: "Evan",
            age: 27,
            mbti: "ENTP",
            vibe: "Chill",
            ethnicity: "White",
            religion: "None",
            city: "San Jose",
            badges: ["Wingman"],
            attendanceRating: 4.6,
            attendance: ["Mini Golf"]
        ),
        User(
            name: "Dana",
            age: 29,
            mbti: "ISFP",
            vibe: "Casual",
            ethnicity: "South Asian",
            religion: "Hindu",
            city: "San Francisco",
            badges: ["Best Friend Material"],
            attendanceRating: 4.7,
            attendance: ["Museum"]
        )
    ]
}

