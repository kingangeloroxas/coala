import SwiftUI
import MapKit

// MARK: - Coala Theme

private enum CoalaTheme {
    static let sky      = Color(red: 0.93, green: 0.98, blue: 1.00)
    static let mist     = Color(red: 0.86, green: 0.96, blue: 1.00)
    static let leaf     = Color(red: 0.43, green: 0.79, blue: 0.62)
    static let leafSoft = Color(red: 0.43, green: 0.79, blue: 0.62, opacity: 0.12)
    static let koala    = Color(red: 0.09, green: 0.27, blue: 0.55)
    static let bubble   = Color(.secondarySystemBackground)
}

// MARK: - Onboarding

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var search = LocationSearch()

    // Form fields
    @State private var name: String = ""
    @State private var ageString: String = ""
    @State private var mbti: String = ""
    @State private var ethnicity: String = ""
    @State private var religion: String = ""
    @State private var vibe: String = "Chill"

    // City autocomplete state
    @State private var query: String = ""
    @State private var resolving = false
    @State private var errorText: String? = nil

    // Suggestion visibility + focus + one-tap suppression
    @State private var showSuggestions = false
    @FocusState private var queryFocused: Bool
    @State private var suppressNextQueryChange = false

    private var age: Int? { Int(ageString.trimmingCharacters(in: .whitespaces)) }
    private var hasCity: Bool { !appState.userCity.isEmpty }
    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        age != nil &&
        !mbti.isEmpty &&
        hasCity
    }

    private let mbtiOptions = [
        "INTJ","INTP","ENTJ","ENTP",
        "INFJ","INFP","ENFJ","ENFP",
        "ISTJ","ISFJ","ESTJ","ESFJ",
        "ISTP","ISFP","ESTP","ESFP"
    ]
    private let ethnicityOptions = [
        "Caucasian", "Asian", "Hispanic",
        "African-American", "Native American", "South Asian"
    ]
    private let religionOptions = [
        "Christian", "Catholic", "Buddhist", "Hindu",
        "Jewish", "Atheist", "Agnostic", "Spiritual", "None"
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [CoalaTheme.sky, CoalaTheme.mist],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            LeafBackdrop().allowsHitTesting(false)

            VStack(spacing: 0) {
                AppTopBar(title: "onboarding", onBack: { appState.goBack() })
                KoalaHeader()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {

                        // MARK: Your Details
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                IconField(systemName: "person") {
                                    TextField("name", text: $name)
                                        .textContentType(.name)
                                        .textInputAutocapitalization(.never)
                                        .disableAutocorrection(true)
                                }

                                IconField(systemName: "number") {
                                    TextField("age", text: $ageString)
                                        .keyboardType(.numberPad)
                                        .textInputAutocapitalization(.never)
                                        .disableAutocorrection(true)
                                }

                                HStack(spacing: 10) {
                                    FieldMenu(selection: $mbti, placeholder: "MBTI", options: mbtiOptions)
                                    FieldMenu(selection: $ethnicity, placeholder: "Ethnicity", options: ethnicityOptions)
                                    FieldMenu(selection: $religion, placeholder: "Religion", options: religionOptions)
                                }

                                Picker("Vibe", selection: $vibe) {
                                    Text("Chill").tag("Chill")
                                    Text("Casual").tag("Casual")
                                    Text("Party").tag("Party")
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(.vertical, 6)
                        } label: {
                            SectionHeader(title: "Your Details")
                        }
                        .groupBoxStyle(KoalaGroupBoxStyle())

                        // MARK: Location (city only) with autocomplete
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                if #available(iOS 17.0, *) {
                                    IconField(systemName: "mappin.and.ellipse") {
                                        TextField("enter your city", text: $query)
                                            .focused($queryFocused)
                                            .textInputAutocapitalization(.never)
                                            .disableAutocorrection(true)
                                            .onChange(of: query) { _, newValue in
                                                handleQueryChange(newValue)
                                            }
                                    }
                                } else {
                                    IconField(systemName: "mappin.and.ellipse") {
                                        TextField("enter your city", text: $query)
                                            .focused($queryFocused)
                                            .textInputAutocapitalization(.never)
                                            .disableAutocorrection(true)
                                            .onChange(of: query) { newValue in
                                                handleQueryChange(newValue)
                                            }
                                    }
                                }

                                if showSuggestions && !search.suggestions.isEmpty {
                                    VStack(spacing: 0) {
                                        ForEach(search.suggestions, id: \.self) { s in
                                            Button { pick(s) } label: {
                                                HStack(alignment: .firstTextBaseline) {
                                                    Text(s.title).font(.body)
                                                    if !s.subtitle.isEmpty {
                                                        Text("· \(s.subtitle)")
                                                            .font(.subheadline)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 10)
                                            }
                                            .buttonStyle(.plain)
                                            .contentShape(Rectangle())
                                            Divider()
                                        }
                                    }
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(CoalaTheme.bubble)
                                            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                                    )
                                }

                                if resolving {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                        Text("Confirming city…").foregroundStyle(.secondary)
                                    }
                                } else if !appState.userCity.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "leaf")
                                            .foregroundStyle(CoalaTheme.leaf)
                                        Text("Selected city: \(appState.userCity)")
                                            .foregroundStyle(.secondary)
                                    }
                                } else if let err = errorText {
                                    Text(err).foregroundStyle(.red)
                                }
                            }
                            .padding(.vertical, 6)
                        } label: {
                            SectionHeader(title: "Location")
                        }
                        .groupBoxStyle(KoalaGroupBoxStyle())

                        // MARK: Continue
                        Button {
                            saveAndContinue()
                        } label: {
                            HStack(spacing: 10) {
                                Text("Continue")
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(KoalaFilledButtonStyle(enabled: canContinue))
                        .disabled(!canContinue)

                        Spacer(minLength: 24)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(TapGesture().onEnded {
                    if showSuggestions {
                        showSuggestions = false
                        queryFocused = false
                    }
                })
            }
        }
        .onAppear {
            if !appState.userCity.isEmpty { query = appState.userCity }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Logic

    private func handleQueryChange(_ newValue: String) {
        if suppressNextQueryChange {
            suppressNextQueryChange = false
            return
        }
        errorText = nil
        appState.userCity = ""
        showSuggestions = !newValue.isEmpty && queryFocused
        search.update(fragment: newValue)
    }

    private func saveAndContinue() {
        // If user typed but didn't tap a suggestion, keep their text (trimmed).
        if appState.userCity.isEmpty, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appState.userCity = query.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var u = appState.currentUser
        u.name = name.trimmingCharacters(in: .whitespaces)
        u.age = age ?? 25
        u.mbti = mbti
        u.vibe = vibe
        u.ethnicity = ethnicity
        u.religion = religion

        // ✅ Ensure Matcher sees user's city (saved on the User object)
        u.city = appState.userCity.trimmingCharacters(in: .whitespacesAndNewlines)

        appState.currentUser = u

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        appState.goNextFromOnboarding()
    }

    private func pick(_ completion: MKLocalSearchCompletion) {
        showSuggestions = false
        queryFocused = false
        suppressNextQueryChange = true
        query = completion.title
        search.clear()

        resolving = true
        errorText = nil

        search.resolve(completion) { city in
            DispatchQueue.main.async {
                resolving = false
                if let city, !city.isEmpty {
                    appState.userCity = city
                } else {
                    appState.userCity = ""
                    errorText = "Couldn't extract a city from that address. Try another result."
                }
            }
        }
    }
}

// MARK: - Reusable Menu field (text-only)

private struct FieldMenu: View {
    @Binding var selection: String
    let placeholder: String
    let options: [String]

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { opt in
                Button(opt) { selection = opt } // text-only; no checkmarks
            }
        } label: {
            Text(selection.isEmpty ? placeholder : selection)
                .foregroundStyle(selection.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.gray.opacity(0.32))
                )
        }
    }
}

// MARK: - Header, Sections, Styles

private struct KoalaHeader: View {
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: 76, height: 76)
                    .overlay(
                        Circle()
                            .stroke(CoalaTheme.koala.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)

                Image("coala_icon") // replace with your asset name if different
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
            }

            Text("Welcome to Coala")
                .font(.title2.weight(.semibold))
                .foregroundStyle(CoalaTheme.koala)

            Text("find your group • plan with ease")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf")
                .foregroundStyle(CoalaTheme.leaf)
            Text(title)
                .font(.headline)
        }
    }
}

private struct IconField<Content: View>: View {
    let systemName: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .foregroundStyle(CoalaTheme.koala.opacity(0.85))
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.gray.opacity(0.32))
        )
    }
}

private struct KoalaGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            configuration.label
            configuration.content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CoalaTheme.bubble)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
        )
    }
}

private struct KoalaFilledButtonStyle: ButtonStyle {
    let enabled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(enabled ? CoalaTheme.koala : Color.gray.opacity(0.35))
                    .brightness(configuration.isPressed ? -0.05 : 0)
            )
            .foregroundStyle(.white)
            .shadow(color: enabled ? CoalaTheme.koala.opacity(0.25) : .clear, radius: 10, y: 6)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Subtle decorative backdrop

private struct LeafBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                EucalyptusLeaf()
                    .fill(CoalaTheme.leafSoft)
                    .frame(width: 220, height: 140)
                    .rotationEffect(.degrees(-25))
                    .offset(x: -geo.size.width * 0.28, y: -geo.size.height * 0.22)

                EucalyptusLeaf()
                    .fill(CoalaTheme.leafSoft)
                    .frame(width: 260, height: 160)
                    .rotationEffect(.degrees(15))
                    .offset(x: geo.size.width * 0.32, y: geo.size.height * 0.35)
            }
        }
    }
}

private struct EucalyptusLeaf: Shape {
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

// MARK: - Embedded autocomplete helper

/// Canonicalizes resolved places to formats CityGeo is more likely to recognize.
/// US -> "City, ST"; non-US -> "City, Country".
private func canonicalCityString(from placemark: MKPlacemark) -> String? {
    let city = placemark.locality ?? placemark.subAdministrativeArea
    let state = placemark.administrativeArea
    if placemark.isoCountryCode == "US" {
        if let c = city, let s = state { return "\(c), \(s)" }
        if let c = city { return c }
        if let s = state { return s }
        return nil
    } else {
        if let c = city, let country = placemark.country { return "\(c), \(country)" }
        if let c = city { return c }
        return placemark.country
    }
}

final class LocationSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = MKCoordinateRegion(.world)
    }

    func update(fragment: String) {
        completer.queryFragment = fragment
        if fragment.isEmpty { suggestions = [] }
    }

    func clear() {
        suggestions = []
        completer.queryFragment = ""
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }

    func resolve(_ completion: MKLocalSearchCompletion, done: @escaping (String?) -> Void) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            if let pm = response?.mapItems.first?.placemark {
                done(canonicalCityString(from: pm))
            } else {
                done(nil)
            }
        }
    }
}

