import SwiftUI

// iOS 16/17 safe onChange wrapper
private extension View {
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            return AnyView(self.onChange(of: value) { _, newValue in action(newValue) })
        } else {
            return AnyView(self.onChange(of: value) { v in action(v) })
        }
    }
}

// Brand palette (two distinct blues)
private enum Brand {
    // Activity card fill (slightly darker)
    static let activityBlue = Color(hue: 210/360, saturation: 0.28, brightness: 0.92)
    // Group size card fill (lighter blue, so text pops)
    static let groupBlue    = Color(hue: 205/360, saturation: 0.40, brightness: 0.88)

    static let borderLight  = Color.white.opacity(0.20)
    static let borderSoft   = Color.black.opacity(0.10)

    static let darkBlueText = Color(red: 0.09, green: 0.27, blue: 0.55)
}

struct MatchingView: View {
    @EnvironmentObject var appState: AppState

    // Local state
    @State private var isMatching = false
    @State private var matchedGroup: [User] = []

    // Ensure the animation plays long enough to be seen
    @State private var matchStartedAt: Date? = nil
    private let minAnimationDuration: TimeInterval = 2.0

    // Settings UI state
    @State private var genderModeLocal: GenderMode = .any
    @State private var distanceIndex: Int = 0
    private let distanceOptions: [Int] = [10, 20, 30, 40, 50]

    @State private var showFilterSheet = false
    @State private var filterSettings = FilterSettings()

    private var showsSettings: Bool { !isMatching && matchedGroup.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // ===== Top: filters + selection row =====
            if showsSettings {
                VStack(spacing: 12) {
                    settingsPanel
                    selectionRow
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)
            }

            // ===== Content =====
            SwiftUI.Group {
                if isMatching {
                    CoalaBoatWaveView()
                        .transition(.opacity)
                        .ignoresSafeArea()
                } else if matchedGroup.isEmpty {
                    VStack(spacing: 12) {
                        Text("Ready to Match?")
                            .font(.custom("Avenir-Heavy", size: 28))
                        Text("We’ll find a group you'll vibe with!")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else {
                    List {
                        Section("Your group") {
                            ForEach(matchedGroup, id: \.id) { u in
                                MatchRow(u: u)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }

            // ===== Primary button =====
            if !isMatching {
                Button(action: primaryAction) {
                    Text(matchedGroup.isEmpty ? "Match Me!" : "Go to Chat")
                        .font(.custom("Avenir-Heavy", size: 17))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Brand.darkBlueText)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
        }
        .navigationBarBackButtonHidden(false)
        .onAppear(perform: syncSettingsFromState)
        .onChangeCompat(of: genderModeLocal) { appState.genderMode = $0 }
        .onChangeCompat(of: distanceIndex) { newIndex in
            appState.distanceCutoffMiles = Double(distanceOptions[newIndex])
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterView(settings: $filterSettings) {
                showFilterSheet = false
            }
        }
    }

    // MARK: - Selection row
    @ViewBuilder private var selectionRow: some View {
        HStack(spacing: 12) {
            // Activity card (left) — safe optional title
            Button { appState.goToActivity() } label: {
                SquareSelectionCard(
                    fill: Brand.activityBlue,
                    border: Brand.borderSoft,
                    titleColor: Brand.darkBlueText,
                    height: 110,
                    emoji: activityEmoji(for: appState.selectedActivity),
                    title: (appState.selectedActivity?.isEmpty == false)
                         ? (appState.selectedActivity ?? "")
                         : "Activity",
                    fitTitleToHeight: false,
                    useAvenirBold: false
                )
            }
            .buttonStyle(.plain)

            // Group size card (right) — lighter blue, white bold Avenir, no icon
            Button { appState.goToGroupSize() } label: {
                SquareSelectionCard(
                    fill: Brand.groupBlue,
                    border: Brand.borderLight,
                    titleColor: Brand.darkBlueText,
                    height: 110,
                    emoji: nil,
                    title: (appState.selectedGroupSize != nil)
                         ? "\(appState.selectedGroupSize!) people"
                         : "Group size",
                    fitTitleToHeight: true,
                    useAvenirBold: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Shared square card
    private struct SquareSelectionCard: View {
        let fill: Color
        let border: Color
        let titleColor: Color
        let height: CGFloat
        let emoji: String?
        let title: String
        let fitTitleToHeight: Bool
        let useAvenirBold: Bool

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fill)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(border, lineWidth: 1)

                content
                    .foregroundStyle(titleColor)
                    .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }

        @ViewBuilder
        private var content: some View {
            if fitTitleToHeight {
                // Title scales to fill height (no emoji expected here)
                GeometryReader { geo in
                    let H = geo.size.height
                    let size = max(18, H * 0.32) // ~32% of height (reduced from 40%)
                    HStack {
                        Text(title)
                            .font(.system(size: size, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            } else {
                // Standard layout: optional emoji + title
                VStack(spacing: 4) {
                    if let emoji {
                        Text(emoji).font(.system(size: 28))
                    }
                    Text(title)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }

    // MARK: - Settings panel
    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row: title + Filter button (keeps button visually inside box)
            HStack {
                Text("Group preference")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showFilterSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .symbolRenderingMode(.monochrome)
                        Text("Filter")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open additional filters")
            }

            // Gender preference control
            Picker("", selection: $genderModeLocal) {
                Text("Co-ed").tag(GenderMode.any as GenderMode)
                Text("Same gender").tag(GenderMode.sameGender as GenderMode)
            }
            .pickerStyle(.segmented)

            // Distance cut-off
            VStack(alignment: .leading, spacing: 8) {
                Text("Max distance").font(.caption).foregroundStyle(.secondary)
                HStack {
                    VStack(spacing: 6) {
                        Slider(
                            value: Binding<Double>(
                                get: { Double(distanceIndex) },
                                set: { distanceIndex = Int($0.rounded()) }
                            ),
                            in: 0...Double(distanceOptions.count - 1),
                            step: 1
                        )
                        SliderTicksTrackAligned(stopCount: distanceOptions.count)
                            .frame(height: 8)
                            .opacity(0.7)
                    }
                    Text("\(distanceOptions[distanceIndex]) mi")
                        .font(.custom("Avenir-Heavy", size: 20))
                        .frame(width: 56, alignment: .trailing)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }

    private struct SliderTicksTrackAligned: View {
        let stopCount: Int
        let leadingInset: CGFloat = 16
        let trailingInset: CGFloat = 16

        var body: some View {
            GeometryReader { geo in
                let trackW = max(geo.size.width - leadingInset - trailingInset, 1)
                let stops = max(stopCount, 2)
                Path { path in
                    for i in 0..<stops {
                        let t = CGFloat(i) / CGFloat(stops - 1)
                        let x = leadingInset + t * trackW
                        let h: CGFloat = (i == 0 || i == stops - 1) ? 8 : 6
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: h))
                    }
                }
                .stroke(Color.gray.opacity(0.35), lineWidth: 1)
            }
        }
    }

    private func syncSettingsFromState() {
        genderModeLocal = appState.genderMode
        let currentMiles = Int(appState.distanceCutoffMiles)
        distanceIndex = distanceOptions.firstIndex(of: currentMiles) ?? 0
        appState.distanceCutoffMiles = Double(distanceOptions[distanceIndex])
    }

    // MARK: - Helpers
    private func activityEmoji(for selected: String?) -> String? {
        guard let name = selected, !name.isEmpty else { return "🎉" }
        switch name.lowercased() {
        case "hiking": return "🥾"
        case "pool": return "🎱"
        case "movie": return "🎬"
        case "pickleball": return "🎾"
        case "karaoke": return "🎤"
        case "coffee": return "☕️"
        case "golf": return "⛳️"
        case "museum": return "🖼️"
        case "yoga": return "🧘"
        case "boba": return "🧋"
        case "brunch": return "🥞"
        case "surfing": return "🏄‍♂️"
        case "pumpkin patch": return "🎃"
        case "theme park": return "🎢"
        default: return "🎉"
        }
    }

    // MARK: - (Placeholder) Matching filters — scaffolded, NO-OP for now
    /// Returns a filtered copy of `pool` using the current filter settings.
    /// NOTE: This is intentionally a NO-OP today so filters do not affect matching yet.
    /// To enable later, implement the TODOs below and swap `poolToUse` in `runMatching()` to `filteredPool`.
    private func applyFilters(_ pool: [User], me: User, settings: FilterSettings) -> [User] {
        var result = pool

        // TODO: Ethnicity filter example (once your `User` model supports it)
        // if !settings.selectedEthnicities.isEmpty {
        //     result = result.filter { u in
        //         guard let eth = u.ethnicity else { return false }
        //         return settings.selectedEthnicities.contains(eth)
        //     }
        // }

        // TODO: Max age gap
        // result = result.filter { abs($0.age - me.age) <= settings.maxAgeGap }

        // TODO: "Match with same…" traits: these are soft constraints, so consider boosting
        // compatibility weights instead of hard filtering. Example:
        // if settings.sameTraits.contains(.city) {
        //     // increase weight for same city in your Matcher/weights.
        // }

        return result
    }

    // MARK: - Actions
    private func primaryAction() {
        if matchedGroup.isEmpty { runMatching() }
        else {
            appState.matchedUsers = matchedGroup
            appState.currentScreen = .chat
        }
    }

    private func runMatching() {
        isMatching = true
        matchedGroup = []
        matchStartedAt = Date()
        let targetSize = appState.selectedGroupSize ?? 4

        var me = appState.currentUser

        // Safely sync city & activity from selections if missing on user
        let currentCity = (me.city as String?) ?? ""
        if currentCity.isEmpty, !appState.userCity.isEmpty { me.city = appState.userCity }

        let activityEmpty = (me.activity?.isEmpty != false)
        if activityEmpty, let act = appState.selectedActivity, !act.isEmpty { me.activity = act }

        var pool = SampleData.users
        // Prepare filtered pool (no-op for now)
        let filteredPool = applyFilters(pool, me: me, settings: filterSettings)
        // Keep behavior IDENTICAL for now: do NOT use filteredPool yet.
        // Later, switch `poolToUse` to `filteredPool`.
        var poolToUse = pool
        if !poolToUse.contains(where: { $0.id == me.id }) { poolToUse.insert(me, at: 0) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let group = Matcher.matchGroup(
                me: me,
                pool: poolToUse,
                desiredSize: targetSize,
                selectedActivity: appState.selectedActivity,
                genderMode: appState.genderMode,
                weights: appState.weights
            )

            let now = Date()
            let elapsed = (matchStartedAt != nil) ? now.timeIntervalSince(matchStartedAt!) : 0
            let extraDelay = max(0, minAnimationDuration - elapsed)

            DispatchQueue.main.asyncAfter(deadline: .now() + extraDelay) {
                matchedGroup = group
                isMatching = false
            }
        }
    }
}

// MARK: - Filter model
private struct FilterSettings {
    var selectedEthnicities: Set<String> = []
    var maxAgeGap: Int = 5
    var sameTraits: Set<FilterTrait> = []
}

private enum FilterTrait: String, CaseIterable, Identifiable {
    case senseOfHumor    = "Sense of humor"
    case conversation    = "Conversation level"
    case spontaneity     = "Spontaneity"
    case socialEnergy    = "Social energy"
    case recreationalUse = "Recreational use"
    var id: String { rawValue }
}

// ===== Match row (optional-safe) =====
private struct MatchRow: View {
    let u: User
    var body: some View {
        let mbti: String = (u.mbti as String?) ?? ""
        let city:  String = (u.city  as String?) ?? ""
        let raw:   String = (u.name  as String?) ?? ""
        let name:  String = raw.isEmpty ? "Friend" : raw

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.custom("Avenir-Heavy", size: 17))
                HStack(spacing: 6) {
                    if !mbti.isEmpty { Text(mbti) }
                    Text("• \(u.age)")
                    if !city.isEmpty { Text("• \(city)") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - FilterView
private struct FilterView: View {
    @Binding var settings: FilterSettings
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Example ethnicity options (feel free to customize)
    private let ethnicityOptions: [String] = [
        "Asian", "Black", "Hispanic", "White", "Middle Eastern",
        "Pacific Islander", "South Asian", "East Asian", "Southeast Asian",
        "Native American"
    ]

    @State private var localSettings = FilterSettings()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // Premium title banner
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .imageScale(.medium)
                        Text("Premium")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .foregroundStyle(Color.primary.opacity(0.9))

                    // ===== Ethnicity (dropdown with checkboxes) =====
                    Card {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(ethnicityOptions, id: \.self) { opt in
                                    Button {
                                        if localSettings.selectedEthnicities.contains(opt) {
                                            localSettings.selectedEthnicities.remove(opt)
                                        } else {
                                            localSettings.selectedEthnicities.insert(opt)
                                        }
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: localSettings.selectedEthnicities.contains(opt) ? "checkmark.square.fill" : "square")
                                                .foregroundColor(.blue)
                                            Text(opt)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            HStack {
                                Text("Ethnicity")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Spacer()
                                if !localSettings.selectedEthnicities.isEmpty {
                                    Text("\(localSettings.selectedEthnicities.count) selected")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    // ===== Max age difference slider =====
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Maximum age difference")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Spacer()
                                Text("\(localSettings.maxAgeGap) yrs")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(localSettings.maxAgeGap) },
                                    set: { localSettings.maxAgeGap = Int($0) }
                                ),
                                in: 0...20,
                                step: 1
                            )
                        }
                    }

                    // ===== Prefer same traits =====
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Prefer same")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            VStack(spacing: 10) {
                                ForEach(FilterTrait.allCases) { trait in
                                    Toggle(trait.rawValue, isOn: Binding(
                                        get: { localSettings.sameTraits.contains(trait) },
                                        set: { isOn in
                                            if isOn { localSettings.sameTraits.insert(trait) }
                                            else { localSettings.sameTraits.remove(trait) }
                                        }
                                    ))
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                                }
                            }
                        }
                    }

                    // Bottom spacing
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Custom premium title with lock in the nav bar
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text("Premium Feature")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Image(systemName: "lock.fill")
                            .imageScale(.small)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        settings = localSettings
                        dismiss()
                        onDone()
                    }
                    .bold()
                }
            }
            .onAppear { localSettings = settings }
        }
    }
}

// Helper Card view for filter UI
private struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(14)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
    }
}

// Simple pill tag grid for multi-select chips
private struct TagGrid: View {
    let allTags: [String]
    @Binding var selected: Set<String>
    let title: String

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(allTags, id: \.self) { tag in
                    let isOn = selected.contains(tag)
                    Button {
                        if isOn { selected.remove(tag) } else { selected.insert(tag) }
                    } label: {
                        Text(tag)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isOn ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(isOn ? Color.blue.opacity(0.35) : Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview {
    MatchingView()
        .environmentObject(AppState())
}
#endif
