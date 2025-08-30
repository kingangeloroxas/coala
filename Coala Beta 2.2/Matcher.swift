import Foundation

// MARK: - Gender matching preference used by Matcher
enum GenderMode: String, CaseIterable, Codable, Identifiable {
    case any
    case sameGender
    case mixedPreferred

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .any:            return "Any"
        case .sameGender:     return "Same only"
        case .mixedPreferred: return "Mixed preferred"
        }
    }
}

// MARK: - Weights for matching algorithm
struct MatchingWeights: Codable, Equatable {
    var activity: Double
    var age: Double
    var distance: Double
    var vibe: Double
    var religion: Double
    var ethnicity: Double

    init(activity: Double = 5.0,
         age: Double = 1.4,
         distance: Double = 1.0,
         vibe: Double = 0.0,        // ⬅️ Vibe disabled by default
         religion: Double = 0.6,
         ethnicity: Double = 1.0) {
        self.activity = activity
        self.age = age
        self.distance = distance
        self.vibe = vibe
        self.religion = religion
        self.ethnicity = ethnicity
    }

    static let `default` = MatchingWeights()
}

extension MatchingWeights {
    func normalized() -> MatchingWeights {
        let sum = activity + age + distance + vibe + religion + ethnicity
        guard sum > 0 else { return self }
        return MatchingWeights(
            activity:  activity  / sum,
            age:       age       / sum,
            distance:  distance  / sum,
            vibe:      vibe      / sum,
            religion:  religion  / sum,
            ethnicity: ethnicity / sum
        )
    }
}

// MARK: - Matcher
struct Matcher {
    private static let ageHalfLifeYears: Double = 5.0
    private static let distanceSoftCapMiles: Double = 10.0
    private static let distanceDecayPerMile: Double = 0.08
    private static let maxDistanceHardCutoffMiles: Double = 50.0
    private static let maxAgeGapHardCutoffYears:   Int    = 8
    private static let tieEpsilon: Double = 1e-6

    private static func normGender(_ g: String) -> String {
        let t = g.trimmingCharacters(in: .whitespacesAndNewlines)
        switch t.lowercased() {
        case "male":   return "Male"
        case "female": return "Female"
        default:       return t
        }
    }

    static func rankCandidates(
        me: User,
        in pool: [User],
        requiredActivity: String?,
        genderMode: GenderMode,
        weights w: MatchingWeights
    ) -> [(user: User, score: Double)] {

        let required = requiredActivity?.trimmingCharacters(in: .whitespacesAndNewlines)
        let myG = normGender(me.gender)

        let filtered: [User] = pool.filter { u in
            guard u.id != me.id else { return false }

            if let act = required, !act.isEmpty {
                let hasActivity =
                    (u.activity?.caseInsensitiveCompare(act) == .orderedSame) ||
                    u.attendance.contains { $0.caseInsensitiveCompare(act) == .orderedSame }
                if !hasActivity { return false }
            }

            if abs(me.age - u.age) >= maxAgeGapHardCutoffYears { return false }
            if let miles = CityGeo.distanceMiles(cityA: me.city, cityB: u.city),
               miles > maxDistanceHardCutoffMiles { return false }

            if genderMode == .sameGender {
                let theirG = normGender(u.gender)
                guard !myG.isEmpty, !theirG.isEmpty,
                      myG.caseInsensitiveCompare(theirG) == .orderedSame
                else { return false }
            }

            return true
        }

        let wN = w.normalized()
        let scored = filtered.map { u -> (User, Double) in
            let sAge       = ageScore(me.age, u.age)
            let sDistance  = distanceScore(me.city, u.city)
            let sVibe      = equalityScore(me.vibe, u.vibe, exact: 1.0, close: 0.5) // weight is 0 by default
            let sEthnicity = equalityScore(me.ethnicity, u.ethnicity, exact: 1.0, close: 0.3)
            let sReligion  = equalityScore(me.religion, u.religion, exact: 1.0, close: 0.5)

            let final = wN.distance*sDistance
                      + wN.age*sAge
                      + wN.vibe*sVibe
                      + wN.ethnicity*sEthnicity
                      + wN.religion*sReligion
            return (u, final)
        }

        return scored.shuffled().sorted { $0.1 > $1.1 }
    }

    static func matchGroup(
        me: User,
        pool: [User],
        desiredSize: Int,
        selectedActivity: String?,
        genderMode: GenderMode,
        weights w: MatchingWeights
    ) -> [User] {
        guard desiredSize > 0 else { return [me] }

        let required = (selectedActivity?.isEmpty ?? true) ? nil : selectedActivity
        var ranked = rankCandidates(
            me: me, in: pool, requiredActivity: required, genderMode: genderMode, weights: w
        )

        let companionsNeeded = max(0, desiredSize - 1)
        guard companionsNeeded > 0 else { return [me] }

        if ranked.isEmpty {
            ranked = rankCandidates(
                me: me, in: pool, requiredActivity: nil, genderMode: genderMode, weights: w
            )
            if ranked.isEmpty { return [me] }
        }

        var chosen: [User] = []
        if ranked.count >= companionsNeeded {
            let cutoff = ranked[companionsNeeded - 1].score
            let strictlyHigher = ranked.prefix { $0.1 > cutoff + tieEpsilon }
            chosen.append(contentsOf: strictlyHigher.map { $0.0 })

            let remaining = companionsNeeded - chosen.count
            if remaining > 0 {
                let tied = ranked.dropFirst(strictlyHigher.count)
                    .prefix { abs($0.1 - cutoff) <= tieEpsilon }
                    .map { $0.0 }
                chosen.append(contentsOf: tied.shuffled().prefix(remaining))
            }
        } else {
            chosen.append(contentsOf: ranked.map { $0.0 })
        }

        return [me] + chosen
    }

    // MARK: - Scoring helpers

    private static func ageScore(_ a: Int, _ b: Int) -> Double {
        let diff = abs(Double(a - b))
        return max(0.0, min(1.0, exp(-diff / ageHalfLifeYears)))
    }

    private static func distanceScore(_ cityA: String?, _ cityB: String?) -> Double {
        guard let d = CityGeo.distanceMiles(cityA: cityA, cityB: cityB) else { return 0.5 }
        let extra = max(0.0, d - distanceSoftCapMiles)
        let penalty = extra * distanceDecayPerMile
        return max(0.0, 1.0 - penalty)
    }

    private static func equalityScore(_ a: String, _ b: String, exact: Double, close: Double) -> Double {
        let aT = a.trimmingCharacters(in: .whitespacesAndNewlines)
        let bT = b.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !aT.isEmpty, !bT.isEmpty else { return 0.0 }
        return (aT.caseInsensitiveCompare(bT) == .orderedSame) ? exact : close
    }
}

