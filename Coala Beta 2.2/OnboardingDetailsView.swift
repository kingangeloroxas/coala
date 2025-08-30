import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - Theme (local to this file)
private enum CoalaTheme2 {
    static let sky      = Color(red: 0.93, green: 0.98, blue: 1.00)
    static let mist     = Color(red: 0.86, green: 0.96, blue: 1.00)
    static let leaf     = Color(red: 0.43, green: 0.79, blue: 0.62)
    static let koala    = Color(red: 0.09, green: 0.27, blue: 0.55)
    static let bubble   = Color(.secondarySystemBackground)
}

// MARK: - Helpers
private extension View {
    // iOS 16/17 safe onChange wrapper
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            return AnyView(self.onChange(of: value) { _, newValue in action(newValue) })
        } else {
            return AnyView(self.onChange(of: value) { v in action(v) })
        }
    }
}

// MARK: - Chip layout
private enum ChipLayout { case grid3, singleRowEqual }

// MARK: - Steps
private enum OnbStep: Int, CaseIterable {
    case humor, depth, leadership, spontaneity, socialEnergy, substances

    var isPersonality: Bool { self != .substances }

    var title: String {
        switch self {
        case .humor:         return "Sense of Humor"
        case .depth:         return "Conversation Depth"
        case .leadership:    return "Leadership"
        case .spontaneity:   return "Spontaneity"
        case .socialEnergy:  return "Social Energy"
        case .substances:    return "Recreation"
        }
    }
    var blurb: String {
        switch self {
        case .humor:         return "What kind of humor tickles your funny bone?"
        case .depth:         return "How deeply do you like conversations to go?"
        case .leadership:    return "What role do you usually play in a group?"
        case .spontaneity:   return "How do you approach plan-making?"
        case .socialEnergy:  return "What’s your typical social energy in a group?"
        case .substances:    return "Expectations around alcohol, smoking, & drug use."
        }
    }
}

// MARK: - Premium micro‑interactions

// Snappy, low‑amplitude selection spring
private struct SelectionSpring: ViewModifier {
    let isSelected: Bool
    @State private var scale: CGFloat = 1.0
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .shadow(color: Color.black.opacity(isSelected ? 0.10 : 0.0),
                    radius: isSelected ? 8 : 0, y: isSelected ? 5 : 0)
            .onChangeCompat(of: isSelected) { sel in
                if sel {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.spring(response: 0.20, dampingFraction: 0.90)) { scale = 1.02 }
                    withAnimation(.easeOut(duration: 0.12).delay(0.10)) { scale = 1.0 }
                } else {
                    withAnimation(.easeInOut(duration: 0.12)) { scale = 1.0 }
                }
            }
    }
}
private extension View { func selectionSpring(_ b: Bool) -> some View { modifier(SelectionSpring(isSelected: b)) } }

// Press‑down feedback (tap depress)
private struct PressFeedback: ViewModifier {
    @GestureState private var pressed = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .gesture(DragGesture(minimumDistance: 0).updating($pressed) { _, st, _ in st = true })
    }
}
private extension View { func pressFeedback() -> some View { modifier(PressFeedback()) } }

// Subtle one‑shot ripple on selection
private struct Ripple: View {
    @State private var anim = false
    var body: some View {
        Circle()
            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            .scaleEffect(anim ? 1.25 : 0.6)
            .opacity(anim ? 0.0 : 1.0)
            .onAppear { withAnimation(.easeOut(duration: 0.35)) { anim = true } }
            .allowsHitTesting(false)
    }
}

// Optional diagonal sheen (iOS 17+)
@available(iOS 17.0, *)
private struct Sheen: View {
    @State private var x: CGFloat = -1.0
    var body: some View {
        LinearGradient(stops: [
            .init(color: .white.opacity(0.0),  location: 0.00),
            .init(color: .white.opacity(0.35), location: 0.50),
            .init(color: .white.opacity(0.0),  location: 1.00),
        ], startPoint: .top, endPoint: .bottom)
        .rotationEffect(.degrees(25))
        .offset(x: x * 120)
        .onAppear { withAnimation(.easeOut(duration: 0.45)) { x = 1.2 } }
        .allowsHitTesting(false)
    }
}

// ======================================================================
// MARK: - MAIN VIEW
// ======================================================================
struct OnboardingDetailsView: View {
    @EnvironmentObject var appState: AppState
    @State private var didCheckCompletion = false

    // Personality fields
    @SceneStorage("onb.humor")         private var humor: String = ""
    @SceneStorage("onb.convDepth")     private var conversationDepth: String = ""
    @SceneStorage("onb.leadership")    private var leadership: String = ""
    @SceneStorage("onb.spontaneity")   private var spontaneity: String = ""
    @SceneStorage("onb.socialEnergy")  private var socialEnergy: String = ""

    // Recreation split
    @SceneStorage("onb.alcohol")       private var alcoholUse: String = ""
    @SceneStorage("onb.smoking")       private var smokingUse: String = ""
    @SceneStorage("onb.drugs")         private var drugUse: String = ""

    // Flow state (scene‑persisted)
    @SceneStorage("onb.stepIndex") private var stepIndex: Int = 0

    // Seed support so callers can force a starting step once
    private let startAt: Int?
    @State private var didSeedStart = false

    /// Allow callers to push this view with a specific starting step (e.g. 0 for Humor).
    /// If `nil` (default), we keep whatever `@SceneStorage` had saved.
    init(startAt: Int? = nil) {
        self.startAt = startAt
    }

    private var current: OnbStep { OnbStep.allCases[stepIndex] }
    private var isFinalStep: Bool { stepIndex == OnbStep.allCases.count - 1 }

    private var canProceedFromCurrent: Bool {
        switch current {
        case .humor:        return !humor.isEmpty
        case .depth:        return !conversationDepth.isEmpty
        case .leadership:   return !leadership.isEmpty
        case .spontaneity:  return !spontaneity.isEmpty
        case .socialEnergy: return !socialEnergy.isEmpty
        case .substances:   return !alcoholUse.isEmpty && !smokingUse.isEmpty && !drugUse.isEmpty
        }
    }

    // Chip options
    private let humorChipOptions        = ["Dry", "Witty", "Playful"]
    private let convDepthChipOptions    = ["Light", "Casual", "Deep"]
    private let leadershipChipOptions   = ["Supportive", "Shared", "Assertive"]
    private let spontaneityChipOptions  = ["Planner", "Flexible", "Spontaneous"]
    private let socialEnergyChipOptions = ["Reserved", "Balanced", "Party"]
    private let substancesRowOptions    = ["Never", "Open", "Social"]

    var body: some View {
        ZStack {
            LinearGradient(colors: [CoalaTheme2.sky, CoalaTheme2.mist],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .overlay(LeafBackdrop2().allowsHitTesting(false))

            VStack(spacing: 0) {
                header
                StepDots(current: stepIndex, total: OnbStep.allCases.count)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 18) {
                        if current != .substances {
                            PersonalityStepPage(
                                graphicName: graphicNameForStep(current),
                                title: current.title,
                                blurb: current.blurb,
                                options: optionsForStep(current),
                                selection: bindingForStep(current),
                                explain: explainForStep(current),
                                layout: .singleRowEqual
                            )
                            .padding(.horizontal, 20)

                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                CenteredTraitGraphic(name: graphicNameForStep(current))
                                    .frame(maxWidth: .infinity, alignment: .center)

                                Text(current.title)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(CoalaTheme2.koala)

                                Text("Expectations around alcohol, smoking, & drug use.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 16) {
                                    substanceRow(title: "Alcohol", selection: $alcoholUse)
                                    substanceRow(title: "Smoking", selection: $smokingUse)
                                    substanceRow(title: "Drugs",   selection: $drugUse)
                                }
                                .padding(.top, 2)
                            }
                            .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        }
        .overlay(backButton, alignment: .topLeading)
        .overlay(nextFAB, alignment: .bottomTrailing)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { seedStartIfNeeded(); checkOnboardingCompletion() }
    }

    private func seedStartIfNeeded() {
        guard !didSeedStart else { return }
        if let s = startAt {
            stepIndex = max(0, min(OnbStep.allCases.count - 1, s))
        }
        didSeedStart = true
    }

    /// If the signed-in user has already completed onboarding, jump straight to Hub.
    private func checkOnboardingCompletion() {
        guard !didCheckCompletion else { return }
        didCheckCompletion = true

        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snap, _ in
            guard let data = snap?.data() else { return }

            // Prefer explicit flag if present
            if let done = data["onboardingComplete"] as? Bool, done {
                appState.goToHub()
                return
            }

            // Fallback heuristic: if traits exist with core fields, consider complete
            if let traits = data["traits"] as? [String: Any] {
                let hasHumor = traits["Sense of humor"] as? String
                let hasDepth = traits["Conversation level"] as? String
                let hasSocial = traits["Social energy"] as? String
                let hasAlcohol = traits["Alcohol"] as? String
                let hasSmoking = traits["Smoking"] as? String
                let hasDrugs = traits["Drugs"] as? String
                let coreOK = [hasHumor, hasDepth, hasSocial, hasAlcohol, hasSmoking, hasDrugs].allSatisfy { ($0 ?? "").isEmpty == false }
                if coreOK { appState.goToHub() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Getting to know you")
                .font(.title3.weight(.semibold))
                .foregroundStyle(CoalaTheme2.koala)
            Text("help us match you better!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    // MARK: - Overlays
    @ViewBuilder private var backButton: some View {
        if stepIndex > 0 {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { stepIndex -= 1 }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
            }
            .padding(.top, 12)
            .padding(.leading, 16)
        }
    }

    @ViewBuilder private var nextFAB: some View {
        if canProceedFromCurrent {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                    if isFinalStep { saveAndFinish() } else { stepIndex += 1 }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.98), CoalaTheme2.sky.opacity(0.95)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 8)

                    Image(systemName: isFinalStep ? "checkmark" : "arrow.right")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(CoalaTheme2.koala)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Helpers
    private func substanceRow(title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            FunChipGroup(prompt: "",
                         options: substancesRowOptions,
                         selection: selection,
                         layout: .singleRowEqual)
        }
    }

    private func bindingForStep(_ step: OnbStep) -> Binding<String> {
        switch step {
        case .humor:        return $humor
        case .depth:        return $conversationDepth
        case .leadership:   return $leadership
        case .spontaneity:  return $spontaneity
        case .socialEnergy: return $socialEnergy
        case .substances:   return .constant("")
        }
    }

    private func optionsForStep(_ step: OnbStep) -> [String] {
        switch step {
        case .humor:        return humorChipOptions
        case .depth:        return convDepthChipOptions
        case .leadership:   return leadershipChipOptions
        case .spontaneity:  return spontaneityChipOptions
        case .socialEnergy: return socialEnergyChipOptions
        case .substances:   return []
        }
    }

    // UPDATED: more conversational + informative descriptions
    private func explainForStep(_ step: OnbStep) -> [String: String] {
        switch step {
        case .humor:
            return [
                "Dry": "Straight face, sly timing, and jokes that land a second later. Great with people who enjoy subtle wordplay over big punchlines.",
                "Witty": "Fast connections and clever one‑liners. You like lively back‑and‑forth without putting anyone down.",
                "Playful": "Light teasing and running bits. You keep the vibe warm, welcoming, and a little goofy—in a good way."
            ]
        case .depth:
            return [
                "Light": "Keep it breezy while trust builds—stories, highlights, everyday life. Perfect for new groups and first meets.",
                "Casual": "A mix of fun and a little meaning when it fits. You read the room and go as deep as the moment invites.",
                "Deep": "You enjoy values, purpose, and real talk early. Not heavy—just thoughtful and curious about what matters."
            ]
        case .leadership:
            return [
                "Supportive": "You're present, gives input when asked, remind the group. You keep momentum going without steering the ship.",
                "Shared": "You like planning together and rotating roles as needed. Decisions feel fair because everyone has a say.",
                "Assertive": "You’re comfortable taking point and making clear calls when needed. Efficient, listens to input, takes the lead."
            ]
        case .spontaneity:
            return [
                "Planner": "You love clarity—time, place, who’s bringing what. Fewer surprises means more fun when you get there.",
                "Flexible": "Happy to plan or improvise. You adapt to the group and keep things moving without fuss.",
                "Spontaneous": "You live for last‑minute ideas and quick pivots—energy up, plans light, up to make fun memories."
            ]
        case .socialEnergy:
            return [
                "Reserved": "You warm up with time and smaller circles. Present and thoughtful; you share more as comfort grows.",
                "Balanced": "You switch between listening and leading. You read the vibe and match it naturally.",
                "Party": "Chatty and energizing—great at kicking things off and keeping the room lively."
            ]
        case .substances:
            return [:]
        }
    }

    private func graphicNameForStep(_ step: OnbStep) -> String {
        switch step {
        case .humor:        return "coala_laugh"
        case .depth:        return "coala_swim"
        case .leadership:   return "coala_compass"
        case .spontaneity:  return "coala_dice"
        case .socialEnergy: return "coala_bush"
        case .substances:   return "coala_cocktail"
        }
    }

    // Persist the onboarding selections to Firestore (and mirror to AppState).
    private func persistOnboardingSelections() {
        // Mirror to local AppState so ProfileView can read immediately.
        var traits: [String: String] = [
            "Sense of humor": humor,
            "Conversation level": conversationDepth,
            "Leadership": leadership,
            "Spontaneity": spontaneity,
            "Social energy": socialEnergy,
            // "Recreational use" key removed as per instructions
        ]
        // Keep individual substance fields for richer filtering later.
        traits["Alcohol"] = alcoholUse
        traits["Smoking"] = smokingUse
        traits["Drugs"]   = drugUse

        // Update in-memory state immediately.
        appState.traitAnswers = traits

        // If the user is authenticated, write to Firestore.
        guard let uid = Auth.auth().currentUser?.uid else {
            // Not signed in yet; skip remote write for now.
            return
        }

        // Safely derive a non-optional city string
        let cityStored = (appState.currentUser.city ?? "").isEmpty ? appState.userCity : (appState.currentUser.city ?? "")
        let stateStored = (appState.currentUser.state ?? "").isEmpty ? appState.userState : (appState.currentUser.state ?? "")

        let db = Firestore.firestore()
        let payload: [String: Any] = [
            "name": appState.currentUser.name,
            "age": appState.currentUser.age,
            "gender": appState.currentUser.gender,
            "city": cityStored,
            "state": stateStored,
            "religion": appState.currentUser.religion ?? "",
            "traits": traits,
            "onboardingComplete": true,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        db.collection("users").document(uid).setData(payload, merge: true) { err in
            if let err = err {
                print("⚠️ Firestore write failed: \(err.localizedDescription)")
            } else {
                print("✅ Onboarding selections saved for uid \(uid)")
            }
        }
    }

    private func saveAndFinish() {
        let u = appState.currentUser
        appState.applyOnboardingPart(name: u.name, age: u.age, gender: u.gender, city: u.city, state: u.state)

        // Save traits + basics to Firestore (and mirror to AppState).
        persistOnboardingSelections()

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        appState.goToHub()
    }
}

// ======================================================================
// MARK: - Subviews used above
// ======================================================================

// Centered card image
private struct CenteredTraitGraphic: View {
    let name: String
    var body: some View {
        let baseName = (name as NSString).deletingPathExtension
        SwiftUI.Group {
            if let ui = UIImage(named: name) ?? UIImage(named: baseName) {
                Image(uiImage: ui).resizable().scaledToFit()
            } else {
                Image(baseName).resizable().scaledToFit()
            }
        }
        .frame(maxWidth: 210, minHeight: 105)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.9), CoalaTheme2.sky.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CoalaTheme2.koala.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, y: 6)
        .frame(maxWidth: .infinity)
    }
}

// Dots
private struct StepDots: View {
    let current: Int
    let total: Int
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { idx in
                Circle()
                    .fill(idx == current ? CoalaTheme2.koala : Color.gray.opacity(0.28))
                    .frame(width: idx == current ? 10 : 8, height: idx == current ? 10 : 8)
                    .animation(.easeOut(duration: 0.2), value: current)
            }
        }
    }
}

// Personality page
private struct PersonalityStepPage: View {
    let graphicName: String
    let title: String
    let blurb: String
    let options: [String]
    @Binding var selection: String
    let explain: [String: String]
    var layout: ChipLayout = .singleRowEqual

    var detail: String? { explain[selection] }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CenteredTraitGraphic(name: graphicName)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(CoalaTheme2.koala)

            Text(blurb)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            FunChipGroup(prompt: "", options: options, selection: $selection, layout: layout)

            if let d = detail {
                fadingText(d, key: selection)
            }
        }
    }

    @ViewBuilder
    private func fadingText(_ text: String, key: String) -> some View {
        if #available(iOS 17.0, *) {
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .id(key)
                .contentTransition(.opacity)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.28), value: key)
        } else {
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .id(key)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.28), value: key)
        }
    }
}

// Fun chips + group
private struct FunChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var expand: Bool = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack { Spacer(minLength: 0); Text(title).font(.subheadline.weight(.medium)); Spacer(minLength: 0) }
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: expand ? .infinity : nil)
                .background(
                    ZStack {
                        // Base fill
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isSelected ? CoalaTheme2.koala : CoalaTheme2.bubble)

                        // Soft inner glow (kept from before)
                        if isSelected {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(CoalaTheme2.koala.opacity(0.10))
                                .blur(radius: 8)
                                .transition(.opacity)
                                .animation(.easeOut(duration: 0.18), value: isSelected)
                        }

                        // Subtle ripple when chip becomes selected
                        if isSelected {
                            Ripple()
                                .frame(width: 46, height: 28)
                                .transition(.identity)
                        }

                        // Optional sheen (iOS 17+)
                        if #available(iOS 17.0, *), isSelected {
                            Sheen()
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelected ? .clear : Color.gray.opacity(0.28), lineWidth: 1)
                )
                .foregroundStyle(isSelected ? Color.white : .primary)
                .selectionSpring(isSelected)
        }
        .pressFeedback()         // NEW: press‑down
        .buttonStyle(.plain)
    }
}

private struct FunChipGroup: View {
    let prompt: String
    let options: [String]
    @Binding var selection: String
    var layout: ChipLayout = .singleRowEqual

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !prompt.isEmpty {
                Text(prompt)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            switch layout {
            case .grid3:
                LazyVGrid(columns: cols, alignment: .leading, spacing: 12) {
                    ForEach(options, id: \.self) { title in
                        chip(title, expand: false)
                    }
                }
            case .singleRowEqual:
                HStack(spacing: 12) {
                    ForEach(options, id: \.self) { title in
                        chip(title, expand: true)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chip(_ title: String, expand: Bool) -> some View {
        FunChip(
            title: title,
            isSelected: selection == title,
            action: {
                withAnimation(.easeInOut(duration: 0.28)) {
                    selection = title
                }
            },
            expand: expand
        )
    }
}

// Backdrop
private struct LeafBackdrop2: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                EucalyptusLeaf2()
                    .fill(CoalaTheme2.leaf.opacity(0.12))
                    .frame(width: 220, height: 140)
                    .rotationEffect(.degrees(-25))
                    .offset(x: -geo.size.width * 0.28, y: -geo.size.height * 0.22)

                EucalyptusLeaf2()
                    .fill(CoalaTheme2.leaf.opacity(0.12))
                    .frame(width: 260, height: 160)
                    .rotationEffect(.degrees(15))
                    .offset(x: geo.size.width * 0.32, y: geo.size.height * 0.35)
            }
        }
    }
}
private struct EucalyptusLeaf2: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: 0.1*w, y: 0.5*h))
        p.addQuadCurve(to: CGPoint(x: 0.55*w, y: 0.05*h), control: CGPoint(x: 0.15*w, y: 0.05*h))
        p.addQuadCurve(to: CGPoint(x: 0.95*w, y: 0.5*h), control: CGPoint(x: 0.95*w, y: 0.05*h))
        p.addQuadCurve(to: CGPoint(x: 0.55*w, y: 0.95*h), control: CGPoint(x: 0.95*w, y: 0.95*h))
        p.addQuadCurve(to: CGPoint(x: 0.1*w, y: 0.5*h), control: CGPoint(x: 0.15*w, y: 0.95*h))
        return p
    }
}

