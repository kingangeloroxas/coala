import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - Coala Theme (local to this file)
private enum CoalaTheme {
    static let sky      = Color(red: 0.93, green: 0.98, blue: 1.00)
    static let mist     = Color(red: 0.86, green: 0.96, blue: 1.00)
    static let leaf     = Color(red: 0.43, green: 0.79, blue: 0.62)
    static let koala    = Color(red: 0.09, green: 0.27, blue: 0.55)
    static let bubble   = Color(.secondarySystemBackground)
}

// MARK: - Onboarding
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState

    // Local (session-only) state
    @State private var name: String = ""
    @State private var dob: Date = {
        var comps = DateComponents()
        comps.year = 2000; comps.month = 1; comps.day = 1
        return Calendar.current.date(from: comps) ?? Date(timeIntervalSince1970: 946684800) // Jan 1, 2000
    }()
    @State private var gender: String = ""      // "Female" / "Male"
    @State private var ethnicity: String = ""
    @State private var religion: String = ""
    @State private var stateProvince: String = ""
    // Debounced incremental Firestore save
    @State private var saveWorkItem: DispatchWorkItem?
    private let saveDelay: TimeInterval = 0.6

    // LOCATION state
    @StateObject private var search = LocationSearch()
    @SceneStorage("onb.cityQuery") private var cityQuery: String = ""
    @State private var resolving = false
    @State private var errorText: String? = nil
    @State private var showSuggestions = false
    @State private var suppressNextQueryChange = false
    @FocusState private var cityFocused: Bool
    // New state to control Sign Up sheet presentation
    @State private var showSignUpSheet = false
    private let db = Firestore.firestore()

    // Navigation
    private enum Route: Hashable { case signup, details }
    @State private var path: [Route] = []

    // Derived
    private var age: Int {
        let now = Date()
        let comps = Calendar.current.dateComponents([.year], from: dob, to: now)
        return max(0, comps.year ?? 0)
    }
    private var hasCity: Bool { !appState.userCity.isEmpty }
    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        age > 0 &&
        !gender.isEmpty &&
        !ethnicity.isEmpty &&
        !religion.isEmpty &&
        hasCity
    }

    private let ethnicityOptions = [
        "African-American", "Asian", "Caucasian",
        "Hispanic", "Native American", "South Asian"
    ]
    private let religionOptions = [
        "Christian", "Catholic", "Jewish", "Muslim",
        "Hindu", "Buddhist", "Atheist", "Spiritual", "None"
    ]

    // MARK: - Body
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                backgroundLayer
                contentLayer
            }
            .navigationBarBackButtonHidden(true)
            .navigationTitle("")
            .onAppear {
                syncRestoredCityIfNeeded()
                // Present Sign Up first if we don't have an auth email yet
                #if DEBUG
                // If you want to see Sign Up every run while testing, set this true manually
                #endif
                showSignUpSheet = (appState.authEmail.isEmpty)
            }
            .fullScreenCover(isPresented: $showSignUpSheet) {
                AccountSignUpView()
                    .environmentObject(appState)
            }
            .navigationDestination(for: Route.self, destination: destinationView)
            // Auto-save to Firestore as the user fills profile (debounced)
            .onChange(of: name) { new in
                let v = new.trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { scheduleUserUpdate(["name": v]) }
            }
            .onChange(of: gender) { new in
                let g = normalizedGender(new)
                if !g.isEmpty { scheduleUserUpdate(["gender": g]) }
            }
            .onChange(of: dob) { new in
                let payload: [String: Any] = [
                    "dob": Timestamp(date: new),
                    "age": age
                ]
                scheduleUserUpdate(payload)
            }
            .onChange(of: ethnicity) { new in
                if !new.isEmpty { scheduleUserUpdate(["ethnicity": new]) }
            }
            .onChange(of: religion) { new in
                if !new.isEmpty { scheduleUserUpdate(["religion": new]) }
            }
            .onChange(of: appState.userCity) { new in
                if !new.isEmpty { scheduleUserUpdate(["city": new]) }
            }
            .onChange(of: stateProvince) { new in
                if !new.isEmpty { scheduleUserUpdate(["state": new]) }
            }
        }
    }

    // MARK: - Layers

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [CoalaTheme.sky, CoalaTheme.mist],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(LeafBackdrop().allowsHitTesting(false))
    }

    private var contentLayer: some View {
        VStack(spacing: 0) {
            KoalaHeader()
            formScroll
        }
    }

    // MARK: - Scroll + Sections

    private var formScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                profileBox
                locationBox
                continueButton
                Spacer(minLength: 24)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(TapGesture().onEnded(dismissSuggestions))
    }

    private var profileBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                nameField
                genderPicker
                dobField
                Text("Age: \(age)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ethnicityMenu
                religionMenu
            }
            .padding(.vertical, 6)
        } label: {
            SectionHeader(title: "Profile")
        }
        .groupBoxStyle(KoalaGroupBoxStyle())
    }

    private var locationBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                cityField
                citySuggestionsList
                resolvingOrError
            }
            .padding(.vertical, 6)
        } label: {
            SectionHeader(title: "Location")
        }
        .groupBoxStyle(KoalaGroupBoxStyle())
    }

    private var continueButton: some View {
        Button(action: continueTapped) {
            HStack(spacing: 10) {
                Text("Continue")
                Image(systemName: "arrow.right")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canContinue)
    }

    // Allow DOB selection between Jan 1, 1900 and today; default is Jan 1, 2000
    private var datePickerRange: ClosedRange<Date> {
        var startComps = DateComponents(); startComps.year = 1900; startComps.month = 1; startComps.day = 1
        let start = Calendar.current.date(from: startComps) ?? Date(timeIntervalSince1970: -2208988800) // 1900-01-01
        return start...Date()
    }

    // MARK: - Profile controls

    private var nameField: some View {
        IconField(systemName: "person") {
            TextField("name", text: $name)
                .textContentType(.name)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
    }

    private var genderPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Gender", selection: $gender) {
                Text("female").tag("Female")
                Text("male").tag("Male")
            }
            .pickerStyle(.segmented)
        }
    }

    private var dobField: some View {
        IconField(systemName: "calendar") {
            DatePicker("date of birth",
                       selection: $dob,
                       in: datePickerRange,
                       displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .accessibilityLabel("Date of birth")
        }
    }

    private var ethnicityMenu: some View {
        FieldMenu(selection: $ethnicity,
                  placeholder: "Ethnicity",
                  options: ethnicityOptions)
    }

    private var religionMenu: some View {
        FieldMenu(selection: $religion,
                  placeholder: "Religion",
                  options: religionOptions)
    }

    // MARK: - Location controls

    private var cityField: some View {
        IconField(systemName: "mappin.and.ellipse") {
            TextField("enter your city", text: $cityQuery)
                .focused($cityFocused)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onChange(of: cityQuery, perform: handleCityQueryChange)
        }
    }

    @ViewBuilder
    private var citySuggestionsList: some View {
        if showSuggestions && !search.suggestions.isEmpty {
            VStack(spacing: 0) {
                ForEach(search.suggestions, id: \.self) { s in
                    Button { pickCity(s) } label: {
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
                    .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
            )
        }
    }

    @ViewBuilder
    private var resolvingOrError: some View {
        if resolving {
            HStack(spacing: 8) {
                ProgressView()
                Text("Confirming city…").foregroundStyle(.secondary)
            }
        } else if let err = errorText {
            Text(err).foregroundStyle(.red)
        }
    }

    // MARK: - Navigation destination

    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .details:
            // ✅ Start traits flow at the first screen (Humor)
            OnboardingDetailsView()
                .environmentObject(appState)
        case .signup:
            AccountSignUpView()
                .environmentObject(appState)
        }
    }

    // MARK: - Lifecycle helpers

    private func syncRestoredCityIfNeeded() {
        // If the field restored a value but userCity is empty, sync so Continue enables.
        if !cityQuery.isEmpty, appState.userCity.isEmpty {
            appState.userCity = cityQuery
        }
    }

    // MARK: - Actions

    // MARK: - Firestore incremental save (debounced)
    private func scheduleUserUpdate(_ fields: [String: Any]) {
        guard Auth.auth().currentUser?.uid != nil else { return } // only if signed in
        // Cancel any pending write
        saveWorkItem?.cancel()
        // Create a new debounced task
        let work = DispatchWorkItem { upsertUserFields(fields) }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDelay, execute: work)
    }

    private func upsertUserFields(_ fields: [String: Any]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        var toWrite = fields
        toWrite["updatedAt"] = FieldValue.serverTimestamp()

        db.collection("users").document(uid).setData(toWrite, merge: true) { error in
            if let error = error {
                print("⚠️ incremental user save failed: \(error.localizedDescription)")
            } else {
                print("✅ incremental user save merged for uid \(uid)")
            }
        }
    }

    private func dismissSuggestions() {
        if showSuggestions {
            showSuggestions = false
            cityFocused = false
        }
    }

    private func continueTapped() {
        let nameClean = name.trimmingCharacters(in: .whitespaces)
        let ageClean = age

        // Update local state
        var u = appState.currentUser
        u.name      = nameClean
        u.age       = ageClean
        u.gender    = normalizedGender(gender)
        u.ethnicity = ethnicity
        u.city      = appState.userCity
        appState.currentUser = u

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Persist to Firestore if authenticated
        if let uid = Auth.auth().currentUser?.uid {
            let userDoc: [String: Any] = [
                "name": nameClean,
                "age": ageClean,
                "dob": Timestamp(date: dob),
                "gender": normalizedGender(gender),
                "ethnicity": ethnicity,
                "religion": religion,
                "city": appState.userCity,
                "state": stateProvince,
                "onboardingStep": "profile",               // for analytics / progress if desired
                "updatedAt": FieldValue.serverTimestamp()
            ]

            db.collection("users").document(uid).setData(userDoc, merge: true) { error in
                if let error = error {
                    // Soft‑fail: you can surface this more prominently if you prefer
                    print("⚠️ Firestore save failed: \(error.localizedDescription)")
                } else {
                    print("✅ Onboarding (profile) saved for uid \(uid)")
                }
            }
        } else {
            // Not signed in yet — continue UX, but log for debugging
            print("ℹ️ continueTapped: no Auth user; skipping Firestore write")
        }

        // Navigate directly to traits/details
        path.append(.details)
    }

    private func normalizedGender(_ value: String) -> String {
        switch value.lowercased() {
        case "male":   return "Male"
        case "female": return "Female"
        default:       return value
        }
    }

    // MARK: - City behavior

    private func handleCityQueryChange(_ newValue: String) {
        // Ignore programmatic/restore changes and only react when the user is editing.
        if suppressNextQueryChange { suppressNextQueryChange = false; return }
        if !cityFocused { return }

        errorText = nil
        appState.userCity = ""
        showSuggestions = !newValue.isEmpty
        search.update(fragment: newValue)
    }

    private func pickCity(_ completion: MKLocalSearchCompletion) {
        showSuggestions = false
        cityFocused = false
        suppressNextQueryChange = true
        cityQuery = completion.title
        search.clear()

        resolving = true
        errorText = nil

        search.resolve(completion) { city, state, country in
            DispatchQueue.main.async {
                resolving = false
                if let city, !city.isEmpty {
                    appState.userCity = city
                    stateProvince = state ?? ""
                } else {
                    appState.userCity = ""
                    errorText = "Couldn't extract a city from that address. Try another result."
                }
            }
        }
    }
}

// MARK: - Shared UI bits
private struct KoalaHeader: View {
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: 76, height: 76)
                    .overlay(Circle().stroke(CoalaTheme.koala.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)

                Image("coala_question")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
            }

            Text("Let's Get Started!")
                .font(.title2.weight(.semibold))
                .foregroundStyle(CoalaTheme.koala)

            Text("tell us about yourself")
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
            Image(systemName: "leaf").foregroundStyle(CoalaTheme.leaf)
            Text(title).font(.headline)
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

private struct FieldMenu: View {
    @Binding var selection: String
    let placeholder: String
    let options: [String]

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { opt in
                Button(opt) { selection = opt }
            }
        } label: {
            Text(selection.isEmpty ? placeholder : selection)
                .foregroundStyle(selection.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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

private struct LeafBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                EucalyptusLeaf()
                    .fill(CoalaTheme.leaf.opacity(0.12))
                    .frame(width: 220, height: 140)
                    .rotationEffect(.degrees(-25))
                    .offset(x: -geo.size.width * 0.28, y: -geo.size.height * 0.22)

                EucalyptusLeaf()
                    .fill(CoalaTheme.leaf.opacity(0.12))
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

// MARK: - Location helpers
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

// MARK: - Search object
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

    func resolve(_ completion: MKLocalSearchCompletion,
                 done: @escaping (_ city: String?, _ state: String?, _ country: String?) -> Void) {
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, _ in
            if let pm = response?.mapItems.first?.placemark {
                let parts = parseCityStateCountry(from: pm)
                done(parts.city, parts.state, parts.country)
            } else {
                done(nil, nil, nil)
            }
        }
    }
}

private func parseCityStateCountry(from placemark: MKPlacemark) -> (city: String?, state: String?, country: String?) {
    let city = placemark.locality ?? placemark.subAdministrativeArea
    let state = placemark.administrativeArea
    let country = placemark.country
    return (city, state, country)
}

