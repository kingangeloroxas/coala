import Foundation

/// Scoring-based matcher with hard filters:
/// - Activity: hard match (if provided)
/// - Distance: hard cutoff ONLY when distance is known and > 50 miles
/// - Age: hard cutoff at ≥ 8 years difference
/// Tie-breaking: randomized among equal scores
struct Matcher {

    // MARK: - Tunables (weights should sum ~1.0)
    // Priority: activity (hard) → location → age → vibe → ethnicity → religion
    private static let wDistance:  Double = 0.35
    private static let wAge:       Double = 0.25
    private static let wVibe:      Double = 0.20
    private static let wEthnicity: Double = 0.12
    private static let wReligion:  Double = 0.08

    // Age: exponential falloff ~5 years “half-life”
    private static let ageHalfLifeYears: Double = 5.0

    // Distance scoring (after hard cutoff when known)
    private static let distanceSoftCapMiles: Double = 10.0
    private static let distanceDecayPerMile: Double = 0.08   // 8% penalty per mile after cap

    // Hard cutoffs
    private static let maxDistanceHardCutoffMiles: Double = 50.0
    private static let maxAgeGapHardCutoffYears:   Int    = 8   // exclude when |Δage| >= 8

    // Floating-point comparison tolerance for tie detection
    private static let tieEpsilon: Double = 1e-6

    // MARK: - Public API

    /// Rank the pool against `me`, with an optional required activity.
    /// Returns candidates sorted by score (descending).
    /// Equal scores are randomized by shuffling before sort.
    static func rankCandidates(
        me: User,
        in pool: [User],
        requiredActivity: String?
    ) -> [(user: User, score: Double)] {

        let required = requiredActivity?.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered: [User] = pool.filter { u in
            guard u.id != me.id else { return false }

            // Require activity match if provided.
            if let act = required, !act.isEmpty {
                let hasActivity = (u.activity?.caseInsensitiveCompare(act) == .orderedSame)
                  || u.attendance.contains(where: { $0.caseInsensitiveCompare(act) == .orderedSame })
                if !hasActivity { return false }
            }

            // Age hard cutoff
            let ageGap = abs(me.age - u.age)
            if ageGap >= maxAgeGapHardCutoffYears { return false }

            // Distance hard cutoff ONLY when distance is known.
            if let miles = CityGeo.distanceMiles(cityA: me.city, cityB: u.city),
               miles > maxDistanceHardCutoffMiles {
                return false
            }

            return true
        }

        // Score each candidate.
        let scored = filtered.map { u -> (User, Double) in
            let sAge       = ageScore(me.age, u.age)
            let sDistance  = distanceScore(me.city, u.city) // neutral (0.5) if unknown
            let sVibe      = equalityScore(me.vibe, u.vibe, exact: 1.0, close: 0.5)
            let sEthnicity = equalityScore(me.ethnicity, u.ethnicity, exact: 1.0, close: 0.3)
            let sReligion  = equalityScore(me.religion, u.religion, exact: 1.0, close: 0.5)

            let final = wDistance*sDistance + wAge*sAge + wVibe*sVibe + wEthnicity*sEthnicity + wReligion*sReligion
            return (u, final)
        }

        // Shuffle first so equal scores are randomized, then sort by score (desc)
        return scored.shuffled().sorted { $0.1 > $1.1 }
    }

    /// Builds a full group (me + top N-1), with randomized tie-breaking at the cutoff.
    /// If the pool is small, it fills from anyone not yet chosen (respecting the distance cutoff when known).
    static func matchGroup(
        me: User,
        pool: [User],
        desiredSize: Int,
        selectedActivity: String?
    ) -> [User] {
        guard desiredSize > 0 else { return [me] }

        let required = (selectedActivity?.isEmpty ?? true) ? nil : selectedActivity
        let ranked = rankCandidates(me: me, in: pool, requiredActivity: required)

        let companionsNeeded = max(0, desiredSize - 1)
        guard companionsNeeded > 0 else { return [me] }

        if ranked.isEmpty {
            // No eligible candidates (after filtering & cutoffs)
            return [me]
        }

        // Select top companions with randomized tie-breaking at the cutoff.
        var chosen: [User] = []

        if ranked.count >= companionsNeeded {
            let cutoffScore = ranked[companionsNeeded - 1].score
            let strictlyHigher = ranked.prefix { $0.score > cutoffScore + tieEpsilon }
            chosen.append(contentsOf: strictlyHigher.map { $0.user })

            let remaining = companionsNeeded - chosen.count
            if remaining > 0 {
                let tiedAtCutoff = ranked.dropFirst(strictlyHigher.count)
                    .prefix { abs($0.score - cutoffScore) <= tieEpsilon }
                    .map { $0.user }
                let randomSlice = Array(tiedAtCutoff.shuffled().prefix(remaining))
                chosen.append(contentsOf: randomSlice)
            }
        } else {
            chosen.append(contentsOf: ranked.map { $0.user })
        }

        let initialGroup = [me] + chosen
        return fillIfShort(me: me, current: initialGroup, pool: pool, desiredSize: desiredSize)
    }

    // MARK: - Components

    /// 0…1 with steep falloff after ~5 years.
    private static func ageScore(_ a: Int, _ b: Int) -> Double {
        let diff = abs(Double(a - b))
        // exp(-|Δ| / halfLife) → 1.0 at Δ=0, ~0.37 at 5y, ~0.14 at 10y
        return max(0.0, min(1.0, exp(-diff / ageHalfLifeYears)))
    }

    /// 0…1 where ≤softCap miles ≈ 1.0, then decays per mile afterwards.
    /// Unknown distance => neutral 0.5 (candidate allowed by filter).
    private static func distanceScore(_ cityA: String?, _ cityB: String?) -> Double {
        guard let d = CityGeo.distanceMiles(cityA: cityA, cityB: cityB) else {
            return 0.5
        }
        let extra = max(0.0, d - distanceSoftCapMiles)
        let penalty = extra * distanceDecayPerMile
        return max(0.0, 1.0 - penalty)
    }

    /// Exact string match = `exact`, otherwise `close` (or 0 if either empty).
    private static func equalityScore(_ a: String, _ b: String, exact: Double, close: Double) -> Double {
        let aT = a.trimmingCharacters(in: .whitespacesAndNewlines)
        let bT = b.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !aT.isEmpty, !bT.isEmpty else { return 0.0 }
        return (aT.caseInsensitiveCompare(bT) == .orderedSame) ? exact : close
    }

    // MARK: - Helpers

    /// Fill the group from the remaining pool if we came up short (no scoring, excludes duplicates).
    /// Respects hard distance cutoff only when distance is known.
    private static func fillIfShort(me: User, current: [User], pool: [User], desiredSize: Int) -> [User] {
        var group = current
        if group.count < desiredSize {
            let needed = desiredSize - group.count

            let eligibleExtras = pool.filter { u in
                guard u.id != me.id && !group.contains(where: { $0.id == u.id }) else { return false }
                if let miles = CityGeo.distanceMiles(cityA: me.city, cityB: u.city) {
                    return miles <= maxDistanceHardCutoffMiles
                } else {
                    // Unknown distance: allow as extra
                    return true
                }
            }

            group.append(contentsOf: eligibleExtras.shuffled().prefix(needed))
        }
        return group
    }
}

