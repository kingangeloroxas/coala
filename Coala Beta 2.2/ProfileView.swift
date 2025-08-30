// ProfileView.swift
import SwiftUI
import Foundation
import UniformTypeIdentifiers
import MapKit

import FirebaseAuth
import FirebaseFirestore

// MARK: - Notification for Location Change
extension Notification.Name {
    static let userLocationDidChange = Notification.Name("CoalaUserLocationDidChange")
}

// MARK: - Koala Theme Helpers
private enum KoalaTheme {
    static let blue      = Color(red: 0.09, green: 0.27, blue: 0.55) // Koala blue
    static let blueLight = Color(red: 0.87, green: 0.94, blue: 1.00)
    static let bgCard    = Color(.secondarySystemBackground)
    static let stroke    = Color.black.opacity(0.08)
    static let shadow    = Color.black.opacity(0.06)

    static let headerGradient = LinearGradient(
        colors: [Color.white, blueLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// Rounded "glass" card look used across sections
private struct GlassCard: ViewModifier {
    var corner: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(KoalaTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(KoalaTheme.stroke, lineWidth: 1)
            )
            .shadow(color: KoalaTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

private extension View {
    func glassCard(corner: CGFloat = 16) -> some View { modifier(GlassCard(corner: corner)) }
    func sectionTitle(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Spacer(minLength: 0)
        }
        .foregroundStyle(KoalaTheme.blue)
    }
}

// MARK: - Badges: One-stop “levers” to tune layout/size/padding
private enum BadgeLevers {
    static let tilesVisible: CGFloat = 3
    static let interItemSpacing: CGFloat = 12
    static let sideInset: CGFloat = 2
    static let tileWidthScale: CGFloat = 0.80
    static let outerHorizontalPadding: CGFloat = 6
    static let outerVerticalPadding: CGFloat = 6
    static let tileHorizontalPadding: CGFloat = 8
    static let tileVerticalPadding: CGFloat = 8
    static let tileCornerRadius: CGFloat = 14
    static let stripHeight: CGFloat = 106
    static let circleSizeFactor: CGFloat = 0.84
    static let circleSizeMin: CGFloat = 58
    static let circleSizeMax: CGFloat = 80
    static let emojiSizeFactor: CGFloat = 0.50
    static let emojiSizeMin: CGFloat = 26
    static let emojiSizeMax: CGFloat = 36
    static let titleFontSize: CGFloat = 13
}

// New Badge model
private struct Badge: Identifiable, Equatable {
    let id: Int
    let emoji: String
    let title: String
    let subtitle: String
}

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var activitiesMatched: Int = 0   // TODO: wire to AppState
    @State private var activitiesAttended: Int = 0  // TODO: wire to AppState
    @State private var topBranchCount: Int = 0      // TODO: wire to AppState

    @State private var showBadgePicker: Bool = false
    @State private var badgeOrder: [Int] = [0, 1, 2, 3, 4, 5, 6]  // show all badges (reorderable)

    @State private var draggingBadge: Int? = nil
    @State private var showLocationEditor: Bool = false
    @State private var locationDraft: String = ""

    @State private var locationSaveError: String? = nil
    @State private var showLocationSaveAlert: Bool = false

    @State private var didAttemptFetchBasics = false
    @State private var recAlcohol: String? = nil
    @State private var recDrugs: String? = nil
    @State private var recSmoking: String? = nil
    // Personality trait overrides from onboarding/Firestore
    @State private var traitHumor: String? = nil
    @State private var traitConversation: String? = nil
    @State private var traitSpontaneity: String? = nil
    @State private var traitEnergy: String? = nil

    private let sampleBadges: [Badge] = [
        .init(id: 0, emoji: "🌿", title: "Natural Leader", subtitle: "Guides the group with ease"),
        .init(id: 1, emoji: "🪽", title: "Wingman", subtitle: "Always has your back"),
        .init(id: 2, emoji: "💎", title: "#1 Supporter", subtitle: "Cheering others on"),
        .init(id: 3, emoji: "✨", title: "Golden Stamp", subtitle: "Certified reliable"),
        .init(id: 4, emoji: "🌟", title: "Charismatic", subtitle: "Lights up the room"),
        .init(id: 5, emoji: "😂", title: "Funny", subtitle: "Keeps spirits high"),
        .init(id: 6, emoji: "🎉", title: "Party Animal", subtitle: "Life of the party")
    ]

    // Pull name, age, and location from Firestore when missing in memory from onboarding.
    private func fetchUserBasicsIfNeeded() {
        guard !didAttemptFetchBasics else { return }
        didAttemptFetchBasics = true

        // Prefer onboarding/in-memory values first, but ignore placeholder ages (0 or 18)
        let hasName = !appState.currentUser.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let currentAge = resolvedAge(from: appState.currentUser) ?? 0
        let hasReliableAge = (currentAge > 0) && !isPlaceholderAge(currentAge)

        // Always perform Firestore fetch (do not return early)

        guard let uid = Auth.auth().currentUser?.uid else { return }

        Firestore.firestore().collection("users").document(uid).getDocument { snap, err in
            guard err == nil, let data = snap?.data() else { return }
            var updated = appState.currentUser

            if !hasName, let name = data["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.name = name
            }

            // Derive age from multiple schemas; always override placeholder age (0/18)
            if let derived = deriveAge(from: data) {
                if !hasReliableAge || derived != currentAge {
                    updated.age = derived
                }
            }

            // Resolve location from Firestore: prefer `location` (full string), else compose from `city` + `state`
            let fsLocation = (data["location"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fsCity = (data["city"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fsState = (data["state"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

            let composed: String? = {
                if let loc = fsLocation, !loc.isEmpty { return loc }
                if let c = fsCity, !c.isEmpty {
                    if let s = fsState, !s.isEmpty { return "\(c), \(s)" }
                    return c
                }
                return nil
            }()

            if let displayLoc = composed, !isPlaceholderLocation(updated.city ?? appState.userCity) {
                // If current is placeholder/empty, or different from Firestore, update it
                if (updated.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPlaceholderLocation(updated.city ?? "") || displayLoc != updated.city {
                    updated.city = displayLoc
                }
            }

            // Recreational use fields — map to canonical strings ("never" | "open" | "social")
            let alcohol = extractUseField(from: data, keys: [
                "alcoholUse", "alcohol", "drink", "drinkingUse", "drinking",
                "traits.Alcohol", "Alcohol"
            ])
            let drugs   = extractUseField(from: data, keys: [
                "drugUse", "drugs", "recreationalDrugs", "substances", "substanceUse",
                "traits.Drugs", "Drugs"
            ])
            let smoking = extractUseField(from: data, keys: [
                "smokingUse", "smoking", "smoke", "tobaccoUse", "vapeUse",
                "traits.Smoking", "Smoking"
            ])

            // Personality trait fields (free-form strings)
            let fsHumor = extractTraitField(from: data, keys: [
                "traits.Sense of humor", "Sense of humor",
                "humor", "senseOfHumor", "humorStyle", "funnyLevel"
            ])
            let fsConversation = extractTraitField(from: data, keys: [
                "traits.Conversation level", "Conversation level",
                "conversationLevel", "conversation", "conversationDepth", "chatDepth"
            ])
            let fsSpontaneity = extractTraitField(from: data, keys: [
                "traits.Spontaneity", "Spontaneity",
                "spontaneity", "planningStyle", "spontaneousLevel"
            ])
            let fsEnergy = extractTraitField(from: data, keys: [
                "traits.Social energy", "Social energy",
                "socialEnergy", "energy", "extroversion", "introExtro", "vibe"
            ])

            DispatchQueue.main.async {
                // Assign trait overrides from Firestore
                if let v = fsHumor { self.traitHumor = v }
                if let v = fsConversation { self.traitConversation = v }
                if let v = fsSpontaneity { self.traitSpontaneity = v }
                if let v = fsEnergy { self.traitEnergy = v }
                // Assign recreational use overrides from Firestore
                if let alcohol = alcohol { self.recAlcohol = alcohol }
                if let drugs = drugs { self.recDrugs = drugs }
                if let smoking = smoking { self.recSmoking = smoking }
                // Always push to AppState so other screens see it
                if let displayLoc = composed {
                    appState.userCity = displayLoc
                }
                appState.currentUser = updated
            }
        }
    }

    var body: some View {
        let user = appState.currentUser

        ScrollView {
            VStack(spacing: 16) {
                // Header (avatar + name + city + age)
                header(user: user)

                // Stats row
                statsRow

                // Badges (top 3 with picker)
                badgesSection

                // Traits (sample data for now)
                traitsSection

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .task {
            fetchUserBasicsIfNeeded()
        }
        .alert("Couldn’t Save Location", isPresented: $showLocationSaveAlert, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(locationSaveError ?? "Unknown error.")
        })
        .sheet(isPresented: $showLocationEditor) {
            LocationEditSheet(
                current: (appState.currentUser.city ?? appState.userCity),
                onSave: { newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }

                    // 1) Update in-memory state (single source of truth inside the app)
                    appState.userCity = trimmed
                    appState.currentUser.city = trimmed

                    // Try to parse into city/state if provided as "City, ST"
                    let parts = trimmed.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
                    let parsedCity = parts.first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? trimmed
                    let parsedState = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : nil

                    // 2) Persist to Firestore — save a combined `location` + split `city`/`state` for easy querying
                    if let uid = Auth.auth().currentUser?.uid {
                        var payload: [String: Any] = [
                            "location": trimmed,
                            "city": parsedCity
                        ]
                        if let st = parsedState, !st.isEmpty { payload["state"] = st }

                        let docRef = Firestore.firestore()
                            .collection("users")
                            .document(uid)

                        print("[ProfileView] Saving location to users/\(uid): \(payload)")
                        docRef.setData(payload, merge: true) { err in
                            if let err = err {
                                print("[ProfileView] ERROR saving location: \(err.localizedDescription)")
                                // Surface the error to the user
                                locationSaveError = err.localizedDescription
                                showLocationSaveAlert = true
                                return
                            }
                            print("[ProfileView] Location saved successfully.")

                            // Haptic feedback for success
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)

                            // 3) Broadcast so EVERYWHERE updates (Matching, caches, other screens)
                            var info: [AnyHashable: Any] = [
                                "location": trimmed,
                                "city": parsedCity
                            ]
                            if let st = parsedState { info["state"] = st }
                            NotificationCenter.default.post(name: .userLocationDidChange, object: nil, userInfo: info)
                        }
                    } else {
                        // No authenticated user — show an alert so it’s clear why Firebase didn’t update
                        locationSaveError = "You’re not signed in, so we can’t save your location to the cloud."
                        showLocationSaveAlert = true
                    }
                }
            )
        }
    }

    // MARK: Header
    private func header(user: User) -> some View {
        let name = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let initials = initialsFromName(name)

        // Resolve city with visible fallback so it always shows.
        let city: String = {
            let userCity = (user.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let appCity  = appState.userCity.trimmingCharacters(in: .whitespacesAndNewlines)
            if !userCity.isEmpty { return userCity }
            if !appCity.isEmpty { return appCity }
            return "Add your city"
        }()

        // Always format as "Name, age" when age exists
        let ageText: String = {
            if let v = resolvedAge(from: user), v > 0 { return String(v) }
            return ""
        }()
        let displayName = name.isEmpty ? "Your Name" : name
        let nameWithAge = ageText.isEmpty ? displayName : "\(displayName), \(ageText)"

        return ZStack(alignment: .bottomLeading) {
            // Soft gradient backdrop with subtle pattern dots
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(KoalaTheme.headerGradient)
                .overlay(
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 160, height: 160)
                            .offset(x: 140, y: -60)
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 10)
                            .frame(width: 120, height: 120)
                            .offset(x: -120, y: -40)
                    }
                )

            // Foreground content
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle().fill(KoalaTheme.blue.opacity(0.12))
                    Text(initials.isEmpty ? "•" : initials)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(KoalaTheme.blue)
                }
                .frame(width: 58, height: 58)
                .overlay(
                    Circle().stroke(KoalaTheme.stroke, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(nameWithAge)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Button {
                        locationDraft = city
                        showLocationEditor = true
                    } label: {
                        Text(city)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit location")
                }
                Spacer()
            }
            .padding(16)
        }
        .glassCard(corner: 20)
    }

    // MARK: Stats
    private var statsRow: some View {
        HStack(spacing: 12) {
            statPill(title: "Matched", value: activitiesMatched)
            statPill(title: "Attended", value: activitiesAttended)
            statPill(title: "Top Branch", value: topBranchCount)
        }
        .padding(6)
        .glassCard()
    }

    private func statPill(title: String, value: Int) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(KoalaTheme.stroke, lineWidth: 1)
        )
    }

    // MARK: Badges — horizontal scroll (all) + drag-to-reorder
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                let visible = max<CGFloat>(1, BadgeLevers.tilesVisible)
                let interItemSpacing = BadgeLevers.interItemSpacing
                let sideInset = BadgeLevers.sideInset
                let gaps = max(0, visible - 1)
                let available = geo.size.width - (sideInset * 2) - (interItemSpacing * gaps)
                let tileWidth = floor((available / visible) * BadgeLevers.tileWidthScale)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: interItemSpacing) {
                        ForEach(badgeOrder, id: \.self) { id in
                            if let badge = sampleBadges.first(where: { $0.id == id }) {
                                ColorBadgeTile(badge: badge, isDragging: draggingBadge == id, tileWidth: tileWidth)
                                    .onDrag {
                                        draggingBadge = id
                                        return NSItemProvider(object: "\(id)" as NSString)
                                    }
                                    .onDrop(of: [UTType.text], delegate: BadgeDropDelegate(
                                        currentItem: id,
                                        items: $badgeOrder,
                                        dragging: $draggingBadge
                                    ))
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
            }
            .frame(height: BadgeLevers.stripHeight)
        }
        .padding(.horizontal, BadgeLevers.outerHorizontalPadding)
        .padding(.vertical, BadgeLevers.outerVerticalPadding)
        .glassCard()
    }

    // MARK: - Traits (dynamic recreational use rendering)
    private var traitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Personality Stats")

            VStack(spacing: 10) {
                // Sense of humor
                traitRow(label: "Sense of humor") {
                    Text(resolveTraitValue(for: appState.currentUser,
                                           override: traitHumor,
                                           keys: ["humor", "senseOfHumor", "humorStyle", "funnyLevel"]))
                    .font(.subheadline)
                }
                // Conversation level
                traitRow(label: "Conversation level") {
                    Text(resolveTraitValue(for: appState.currentUser,
                                           override: traitConversation,
                                           keys: ["conversationLevel", "conversation", "conversationDepth", "chatDepth"]))
                    .font(.subheadline)
                }
                // Spontaneity
                traitRow(label: "Spontaneity") {
                    Text(resolveTraitValue(for: appState.currentUser,
                                           override: traitSpontaneity,
                                           keys: ["spontaneity", "planningStyle", "spontaneousLevel"]))
                    .font(.subheadline)
                }
                // Social energy
                traitRow(label: "Social energy") {
                    Text(resolveTraitValue(for: appState.currentUser,
                                           override: traitEnergy,
                                           keys: ["socialEnergy", "energy", "extroversion", "introExtro", "vibe"]))
                    .font(.subheadline)
                }
                // Recreational use — dynamic logic per requirements
                traitRow(label: "Recreational use") {
                    recreationalUseView(for: appState.currentUser)
                }
            }
        }
        .padding(14)
        .glassCard()
    }

    /// A reusable row shell so the code stays tidy
    @ViewBuilder
    private func traitRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.white.opacity(0.8))
                )
                .overlay(
                    Capsule().stroke(KoalaTheme.stroke, lineWidth: 1)
                )

            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(KoalaTheme.stroke, lineWidth: 1)
        )
    }

    /// View builder for the "Recreational use" value with per‑item styling
    @ViewBuilder
    private func recreationalUseView(for user: User) -> some View {
        let statuses = recreationalStatuses(for: user)
        // If all three are `never`, just show "never"
        if statuses.values.allSatisfy({ $0 == .never }) {
            Text("never").font(.subheadline)
        } else {
            // Otherwise list the categories that are open/social with specific styling
            HStack(spacing: 0) {
                let ordered: [(key: String, val: UseStatus)] = [
                    ("Alcohol", statuses["alcohol"] ?? .never),
                    ("Smoking", statuses["smoking"] ?? .never),
                    ("Drugs", statuses["drugs"] ?? .never)
                ].filter { $0.val != .never }

                ForEach(Array(ordered.enumerated()), id: \.offset) { idx, pair in
                    let label = pair.key
                    let status = pair.val
                    let styled = Text(label)
                        .font(.subheadline)
                        .foregroundStyle(status == .open ? Color.secondary : Color.primary)
                    if idx > 0 { Text(", ").font(.subheadline) }
                    styled
                }
            }
        }
    }

    private enum UseStatus { case never, open, social }

    /// Aggregate the three statuses from the user model in a robust way, preferring fetched Firestore overrides
    private func recreationalStatuses(for user: User) -> [String: UseStatus] {
        func map(_ s: String?) -> UseStatus {
            switch (s ?? "").lowercased() {
            case "open": return .open
            case "social": return .social
            case "never": return .never
            default: return .never
            }
        }

        // Prefer fetched state overrides; else infer from `user`
        let alcohol = recAlcohol ?? findStringProperty(in: user, keys: ["alcoholUse", "alcohol", "drink", "drinkingUse", "drinking"]) ?? "never"
        let drugs   = recDrugs   ?? findStringProperty(in: user, keys: ["drugUse", "drugs", "recreationalDrugs", "substances", "substanceUse"]) ?? "never"
        let smoking = recSmoking ?? findStringProperty(in: user, keys: ["smokingUse", "smoking", "smoke", "tobaccoUse", "vapeUse"]) ?? "never"

        return [
            "alcohol": map(alcohol),
            "drugs":   map(drugs),
            "smoking": map(smoking)
        ]
    }

    /// Reflect through the User value to find a matching String property (case-insensitive)
    private func findStringProperty(in user: User, keys: [String]) -> String? {
        let wanted = Set(keys.map { $0.lowercased() })
        let mirror = Mirror(reflecting: user)
        for child in mirror.children {
            guard let label = child.label?.lowercased() else { continue }
            if wanted.contains(label) {
                if let val = child.value as? String { return val }
                if let opt = Mirror(reflecting: child.value).children.first?.value as? String { return opt }
            }
        }
        // Also look for a nested preferences/settings bag common in some schemas
        if let dict = userDictionary(user) {
            for k in keys {
                if let v = dict[k] as? String { return v }
                if let v = dict[k.lowercased()] as? String { return v }
            }
        }
        return nil
    }

    /// Attempt to expose a dictionary view if the User model stores a loose bag (best-effort, safe no-op otherwise)
    private func userDictionary(_ user: User) -> [String: Any]? {
        let mirror = Mirror(reflecting: user)
        for child in mirror.children {
            if child.label == "preferences", let dict = child.value as? [String: Any] { return dict }
            if child.label == "settings", let dict = child.value as? [String: Any] { return dict }
            if child.label == "profile", let dict = child.value as? [String: Any] { return dict }
        }
        return nil
    }

    // MARK: - Firebase Field Extractors (moved inside ProfileView)
    /// Extracts a recreational-use value from Firestore data and normalizes to: "never" | "open" | "social"
    private func extractUseField(from data: [String: Any], keys: [String]) -> String? {
        func norm(_ s: String) -> String { s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased() }
        func ciValue(from dict: [String: Any], forKey key: String) -> Any? {
            if let v = dict[key] { return v }
            let lk = key.lowercased()
            if let v = dict[lk] { return v }
            // case-insensitive fallback
            for (k, v) in dict where k.lowercased() == lk { return v }
            return nil
        }
        func str(_ any: Any?) -> String? {
            guard let s = any as? String else { return nil }
            let t = s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        // 1) Direct top-level keys (case-insensitive)
        for key in keys {
            if let v = str(ciValue(from: data, forKey: key)) { let n = norm(v); if ["never","open","social"].contains(n) { return n } }
        }
        // 2) Common nested containers (including `traits`)
        let containers = ["traits","personality","profile","preferences","onboarding","answers","stats"]
        for bucket in containers {
            guard let dict = data[bucket] as? [String: Any] else { continue }
            for key in keys {
                if let v = str(ciValue(from: dict, forKey: key)) { let n = norm(v); if ["never","open","social"].contains(n) { return n } }
            }
        }
        // 3) Dotted path support
        func deepLookup(_ dict: [String: Any], path: [Substring], idx: Int = 0) -> Any? {
            guard idx < path.count else { return nil }
            let key = String(path[idx])
            guard let next = ciValue(from: dict, forKey: key) else { return nil }
            if idx == path.count - 1 { return next }
            guard let sub = next as? [String: Any] else { return nil }
            return deepLookup(sub, path: path, idx: idx + 1)
        }
        for key in keys {
            let parts = key.split(separator: ".")
            if parts.count > 1, let v = str(deepLookup(data, path: parts)) { let n = norm(v); if ["never","open","social"].contains(n) { return n } }
        }
        return nil
    }

    /// Extracts a free-form trait value from Firestore or nested containers; trims whitespace and supports dotted key paths (case-insensitive).
    private func extractTraitField(from data: [String: Any], keys: [String]) -> String? {
        func ciValue(from dict: [String: Any], forKey key: String) -> Any? {
            if let v = dict[key] { return v }
            let lk = key.lowercased()
            if let v = dict[lk] { return v }
            for (k, v) in dict where k.lowercased() == lk { return v }
            return nil
        }
        func str(_ any: Any?) -> String? {
            guard let s = any as? String else { return nil }
            let t = s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        // 1) Direct top-level
        for key in keys {
            if let v = str(ciValue(from: data, forKey: key)) { return v }
        }
        // 2) Common nested containers
        let containers = ["traits","personality","profile","preferences","onboarding","answers","stats"]
        for bucket in containers {
            guard let dict = data[bucket] as? [String: Any] else { continue }
            for key in keys {
                if let v = str(ciValue(from: dict, forKey: key)) { return v }
            }
        }
        // 3) Dotted key paths
        func deepLookup(_ dict: [String: Any], path: [Substring], idx: Int = 0) -> Any? {
            guard idx < path.count else { return nil }
            let key = String(path[idx])
            guard let next = ciValue(from: dict, forKey: key) else { return nil }
            if idx == path.count - 1 { return next }
            guard let sub = next as? [String: Any] else { return nil }
            return deepLookup(sub, path: path, idx: idx + 1)
        }
        for key in keys {
            let parts = key.split(separator: ".")
            if parts.count > 1, let v = str(deepLookup(data, path: parts)) { return v }
        }
        return nil
    }

    /// Resolve a trait string preferring an override, then looking on the User model (via reflection), else returning a placeholder.
    private func resolveTraitValue(for user: User, override: String?, keys: [String], placeholder: String = "—") -> String {
        if let v = override, !v.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty { return v }
        if let fromUser = findStringProperty(in: user, keys: keys) {
            let trimmed = fromUser.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return placeholder
    }

    // MARK: Helpers
    /// Treat empty/whitespace or specific dev defaults as placeholders so we accept Firestore values
    private func isPlaceholderLocation(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        // Common dev default in this project; adjust if your seed data uses different placeholder
        if trimmed == "Irvine, CA" { return true }
        return false
    }

    /// Safely get age as Int whether `User.age` is declared as `Int` or `Int?`.
    private func resolvedAge(from user: User) -> Int? {
        if let direct = (user.age as Any) as? Int { return direct }
        let mirror = Mirror(reflecting: user.age)
        if mirror.displayStyle == .optional, let child = mirror.children.first, let unwrapped = child.value as? Int {
            return unwrapped
        }
        return nil
    }

    /// Some builds default to 18 — treat that as a placeholder so we always try Firestore.
    private func isPlaceholderAge(_ age: Int) -> Bool { age == 0 || age == 18 }

    /// Try to derive an Int age from multiple possible Firestore schemas.
    /// Supports: `age` (Int/Double/NSNumber/String), `dob` / `dateOfBirth` (Timestamp or ISO String).
    private func deriveAge(from data: [String: Any]) -> Int? {
        // 1) Direct numeric age (Int / Double / NSNumber)
        if let ageInt = data["age"] as? Int { return ageInt > 0 ? ageInt : nil }
        if let ageDbl = data["age"] as? Double { return Int(ageDbl) > 0 ? Int(ageDbl) : nil }
        if let ageNum = data["age"] as? NSNumber { return ageNum.intValue > 0 ? ageNum.intValue : nil }
        // 2) `age` as String
        if let ageStr = data["age"] as? String, let parsed = Int(ageStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return parsed > 0 ? parsed : nil
        }
        // 3) DOB fields
        if let ageFromDOB = ageFromDOBFields(in: data) { return ageFromDOB }
        return nil
    }

    /// Extracts age from `dob` / `dateOfBirth` which can be a Firestore Timestamp or an ISO date string (e.g., "1994-03-21").
    private func ageFromDOBFields(in data: [String: Any]) -> Int? {
        let keys = ["dob", "dateOfBirth", "birthdate", "birthDate"]
        for key in keys {
            if let ts = data[key] as? Timestamp {
                return yearsSince(date: ts.dateValue())
            }
            if let dateStr = data[key] as? String, let d = parseISODate(dateStr) {
                return yearsSince(date: d)
            }
        }
        return nil
    }

    /// Parse a simple ISO-like date string.
    private func parseISODate(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let fmts = ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy", "yyyy-MM-dd'T'HH:mm:ssZ"]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for f in fmts {
            df.dateFormat = f
            if let d = df.date(from: trimmed) { return d }
        }
        return nil
    }

    /// Return whole years between a past date and now.
    private func yearsSince(date: Date) -> Int {
        let now = Date()
        let comps = Calendar.current.dateComponents([.year], from: date, to: now)
        return comps.year ?? 0
    }

    private func initialsFromName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let parts = trimmed.split(separator: " ")
        return String(parts.prefix(2).compactMap(\.first))
    }
}

// New colorful badge tile with emoji and text (uniform size, no subtitle)
private struct ColorBadgeTile: View {
    let badge: Badge
    var isDragging: Bool
    var tileWidth: CGFloat

    var body: some View {
        let circleSize = max(BadgeLevers.circleSizeMin,
                             min(tileWidth * BadgeLevers.circleSizeFactor, BadgeLevers.circleSizeMax))
        let emojiSize  = max(BadgeLevers.emojiSizeMin,
                             min(tileWidth * BadgeLevers.emojiSizeFactor, BadgeLevers.emojiSizeMax))

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [
                            Color.white,
                            KoalaTheme.blueLight.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        Circle().stroke(KoalaTheme.stroke, lineWidth: 1)
                    )
                    .shadow(color: KoalaTheme.shadow, radius: 6, x: 0, y: 3)
                    .frame(width: circleSize, height: circleSize)
                    .overlay(
                        Text(badge.emoji)
                            .font(.system(size: emojiSize))
                    )

                if isDragging {
                    Circle()
                        .stroke(Color.blue.opacity(0.35), lineWidth: 3)
                        .frame(width: circleSize + 6, height: circleSize + 6)
                }
            }

            Text(badge.title)
                .font(.system(size: BadgeLevers.titleFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .frame(width: tileWidth)
        .padding(.vertical, BadgeLevers.tileVerticalPadding)
        .padding(.horizontal, BadgeLevers.tileHorizontalPadding)
        .background(
            RoundedRectangle(cornerRadius: BadgeLevers.tileCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BadgeLevers.tileCornerRadius, style: .continuous)
                .stroke(KoalaTheme.stroke, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isDragging)
    }
}

// Drop delegate to reorder items in a horizontal stack
private struct BadgeDropDelegate: DropDelegate {
    let currentItem: Int
    @Binding var items: [Int]
    @Binding var dragging: Int?

    func validateDrop(info: DropInfo) -> Bool { true }

    func dropEntered(info: DropInfo) {
        guard let dragging = dragging,
              dragging != currentItem,
              let fromIndex = items.firstIndex(of: dragging),
              let toIndex = items.firstIndex(of: currentItem) else { return }

        if items[toIndex] != dragging {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                items.move(fromOffsets: IndexSet(integer: fromIndex),
                           toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

// MARK: - Badge Picker (select up to 4)
private struct BadgePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: [Int]
    @State private var tempSelection: Set<Int> = []

    private let allBadges = Array(0..<9) // pretend we have 9 badges in total

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick your top 4 badges")
                    .font(.headline)
                    .padding(.top, 6)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 12) {
                    ForEach(allBadges, id: \.self) { idx in
                        let isOn = tempSelection.contains(idx)
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isOn ? KoalaTheme.blue.opacity(0.18) : Color(.secondarySystemBackground))
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(KoalaTheme.stroke, lineWidth: 1)
                            Image(systemName: "seal.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.secondary)
                            if isOn {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                                    .offset(x: 24, y: -24)
                                    .imageScale(.medium)
                            }
                        }
                        .frame(width: 72, height: 72)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isOn {
                                tempSelection.remove(idx)
                            } else if tempSelection.count < 4 {
                                tempSelection.insert(idx)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(16)
            .onAppear {
                tempSelection = Set(selected.prefix(4))
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selected = Array(tempSelection.prefix(4)).sorted()
                        dismiss()
                    }.bold()
                }
            }
        }
    }
}

// MARK: - City Search Autocomplete (MapKit)
final class CitySearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer: MKLocalSearchCompleter = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address]
        if #available(iOS 17.0, *) {
            completer.filterType = .locationsOnly
        }
    }

    func update(query: String) {
        completer.queryFragment = query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let filtered = completer.results.filter { completion in
            completion.title.contains(",") || completion.subtitle.contains(",")
        }
        DispatchQueue.main.async { self.results = filtered }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { self.results = [] }
    }
}

// MARK: - Location Edit Sheet
private struct LocationEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let onSave: (String) -> Void

    @StateObject private var citySearch = CitySearch()

    init(current: String, onSave: @escaping (String) -> Void) {
        _text = State(initialValue: current)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                TextField("City, State (e.g., Irvine, CA)", text: $text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(false)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                    .onChange(of: text) { newValue in
                        citySearch.update(query: newValue)
                    }

                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !citySearch.results.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(citySearch.results.prefix(10)).indices, id: \.self) { idx in
                                let item = citySearch.results[idx]
                                let combined = item.subtitle.isEmpty ? item.title : "\(item.title), \(item.subtitle)"
                                Button {
                                    text = combined
                                    citySearch.results = []
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                } label: {
                                    HStack {
                                        Image(systemName: "mappin.and.ellipse")
                                            .foregroundColor(.blue)
                                        Text(combined)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                }
                                .background(idx % 2 == 0 ? Color(.systemBackground) : Color(.secondarySystemBackground))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .frame(maxHeight: 220)
                }

                Text("Tap Save to update your city and state. This will be shown on your profile.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .navigationTitle("Edit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.height(220), .medium])
        .presentationDragIndicator(.visible)
    }
}


