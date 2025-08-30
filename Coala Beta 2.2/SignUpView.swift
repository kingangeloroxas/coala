//
//  SignUpView.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/29/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AccountSignUpView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var phone: String = ""      // for OTP later
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var showTerms = false

    private func normalizedDigits(_ s: String) -> String {
        s.filter(\.isNumber)
    }

var body: some View {
    ScrollView {
        VStack(spacing: 16) {
            // Header — compact but professional
            VStack(spacing: 10) {
                Text("Create your account")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(red: 0.09, green: 0.27, blue: 0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 6)
            .padding(.bottom, 12)

            // Card container for fields
            VStack(spacing: 10) {
                sectionLabel("ACCOUNT DETAILS")

                // Email
                fieldRow(icon: "envelope", placeholder: "Email address") {
                    TextField("Email address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                }

                // Password
                fieldRow(icon: "lock", placeholder: "Password (min 8 characters)") {
                    SecureField("Password (min 8 characters)", text: $password)
                        .textInputAutocapitalization(.never)   // prevent random caps
                        .autocorrectionDisabled(true)          // no autocorrect
                        .textContentType(.password)            // smoother typing than .newPassword
                }

                // Phone
                fieldRow(icon: "phone", placeholder: "Phone number") {
                    TextField("Phone number", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )

            // Error
            if let err = errorText {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Sign Up button
            Button(action: signUp) {
                HStack(spacing: 8) {
                    if isLoading { ProgressView().tint(.white) }
                    Text("Sign Up")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid || isLoading)

            // Log In button below Sign Up
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                appState.currentScreen = .login
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle")
                    Text("Log In")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)

            // Terms & Conditions footer
            VStack(spacing: 4) {
                Text("By continuing, you agree to our")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button { showTerms = true } label: {
                    Text("Terms & Conditions")
                        .font(.footnote.weight(.semibold))
                        .underline()
                }
            }
            .padding(.bottom, 4)

            Spacer(minLength: 8)
        }
        .padding(.top, 100)
        .padding(.horizontal, 20)
    }
    .navigationTitle("Sign Up")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showTerms) {
        TermsSheet()
    }
    .toolbar {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
            }
        }
    }
}

    // MARK: - Validation
    private var isFormValid: Bool {
        isValidEmail(email) && password.count >= 8 && isPlausiblePhone(phone)
    }

    private func isValidEmail(_ s: String) -> Bool {
        let pattern = #"^\S+@\S+\.\S+$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    private func isPlausiblePhone(_ s: String) -> Bool {
        let digits = s.filter(\.isNumber)
        return digits.count >= 7
    }

    // MARK: - Action
    private func signUp() {
        guard isFormValid else {
            errorText = "Please enter a valid email, an 8+ character password, and a phone number."
            return
        }
        errorText = nil
        isLoading = true

        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let passwordValue = password
        let phoneDigits = normalizedDigits(phone)

        Auth.auth().createUser(withEmail: emailTrimmed, password: passwordValue) { authResult, authError in
            if let authError = authError {
                DispatchQueue.main.async {
                    self.errorText = authError.localizedDescription
                    self.isLoading = false
                }
                return
            }

            guard let uid = authResult?.user.uid else {
                DispatchQueue.main.async {
                    self.errorText = "Could not get user ID."
                    self.isLoading = false
                }
                return
            }

            // Send a verification email (Firebase Auth handles the email)
            Auth.auth().currentUser?.sendEmailVerification(completion: { _ in })

            // Prepare initial user document for Firestore
            let users = Firestore.firestore().collection("users")
            let now = Timestamp(date: Date())
            let doc: [String: Any] = [
                "uid": uid,
                "email": emailTrimmed,
                "phone": phoneDigits,
                "createdAt": now,
                "updatedAt": now,
                // Placeholders you can backfill from onboarding later:
                "name": "",
                "age": NSNull(),
                "gender": "",
                "ethnicity": "",
                "city": "",
                "state": "",
                "traits": [
                    "Sense of humor": "",
                    "Conversation level": "",
                    "Leadership": "",
                    "Spontaneity": "",
                    "Social energy": "",
                    "Alcohol": "",
                    "Smoking": "",
                    "Drugs": ""
                ],
                // Temporary, filled before matching:
                "selectedActivity": "",
                "selectedGroupSize": NSNull()
            ]

            users.document(uid).setData(doc, merge: true) { writeError in
                // Clean up any legacy redundant keys if they exist
                users.document(uid).updateData([
                    "traits.Alcohol preference": FieldValue.delete(),
                    "traits.Smoking preference": FieldValue.delete(),
                    "traits.Drugs preference": FieldValue.delete(),
                    "traits.Recreational use": FieldValue.delete()
                ]) { _ in }
                DispatchQueue.main.async {
                    if let writeError = writeError {
                        self.errorText = "Account created, but failed to save profile: \(writeError.localizedDescription)"
                        self.isLoading = false
                        return
                    }

                    // Persist minimal auth info locally if desired
                    UserDefaults.standard.set(emailTrimmed, forKey: "auth.email")
                    UserDefaults.standard.set(phoneDigits, forKey: "auth.phone")

                    self.isLoading = false
                    self.appState.currentScreen = .login
                }
            }
        }
    }
}

// Lightweight Terms modal until a real screen exists
private struct TermsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text("These are placeholder Terms & Conditions. Replace with your legal copy.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Terms & Conditions")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

// MARK: - Login

struct LoginView: View {
    @EnvironmentObject var appState: AppState

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with Home button (matches ActivitySelection style)
            ZStack {
                HStack {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        appState.currentScreen = .splash          // navigate to splash page
                    }) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Home")

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)
            }

            // Existing content
            ScrollView {
                VStack(spacing: 16) {
                    // Header (left-aligned to match Sign Up)
                    VStack(spacing: 10) {
                        Text("Log in")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color(red: 0.09, green: 0.27, blue: 0.55))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                    // Card container for fields
                    VStack(spacing: 10) {
                        sectionLabel("ACCOUNT")

                        // Email
                        fieldRow(icon: "envelope", placeholder: "Email address") {
                            TextField("Email address", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                        }

                        // Password
                        fieldRow(icon: "lock", placeholder: "Password") {
                            SecureField("Password", text: $password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .textContentType(.password)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )

                    // Error
                    if let err = errorText {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Log In button
                    Button(action: logIn) {
                        HStack(spacing: 8) {
                            if isLoading { ProgressView().tint(.white) }
                            Text("Log In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid || isLoading)

                    // Footer: go back to Sign Up (clickable)
                    HStack(spacing: 6) {
                        Text("Need an account?")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            appState.currentScreen = .signup
                        }) {
                            Text("Sign up")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 8)
                }
                .padding(.top, 100)
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("Log In")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    // Validation
    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }

    // Action
    private func logIn() {
        guard isFormValid else {
            errorText = "Please enter your email and password."
            return
        }
        errorText = nil
        isLoading = true

        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let passwordValue = password

        Auth.auth().signIn(withEmail: emailTrimmed, password: passwordValue) { result, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorText = error.localizedDescription
                    return
                }

                // Minimal local state updates; adjust to your AppState model as needed
                UserDefaults.standard.set(emailTrimmed, forKey: "auth.email")
                appState.authEmail = emailTrimmed

                // After login, normalize trait keys before navigation
                if let uid = Auth.auth().currentUser?.uid {
                    normalizeTraitKeys(for: uid) {
                        // After normalization, decide next screen based on onboarding completion.
                        routePostAuth(for: uid)
                    }
                    return
                }
                // If for some reason no UID, just proceed
                appState.currentScreen = .onboarding
            }
        }
    }
    // Helper to decide next screen after login or normalization
    private func routePostAuth(for uid: String) {
        let users = Firestore.firestore().collection("users")
        users.document(uid).getDocument { docSnap, _ in
            guard let data = docSnap?.data() else {
                DispatchQueue.main.async {
                    self.appState.currentScreen = .onboarding
                }
                return
            }
            if isOnboardingComplete(data: data) {
                DispatchQueue.main.async {
                    self.appState.currentScreen = .hub
                }
            } else {
                DispatchQueue.main.async {
                    self.appState.currentScreen = .onboarding
                }
            }
        }
    }

    // Helper to check onboarding completion logic
    private func isOnboardingComplete(data: [String: Any]) -> Bool {
        // Check onboardingStep
        if let step = data["onboardingStep"] as? String,
           step.lowercased() == "done" || step.lowercased() == "complete" {
            return true
        }
        // Check for required fields
        let requiredFields = ["name", "gender", "ethnicity", "religion", "city", "state"]
        for key in requiredFields {
            if let v = data[key] as? String, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            } else {
                return false
            }
        }
        // Traits: must have at least 5 non-empty values
        if let traits = data["traits"] as? [String: Any] {
            let nonEmptyTraits = traits.values.compactMap { val in
                if let s = val as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return s
                }
                return nil
            }
            if nonEmptyTraits.count >= 5 {
                return true
            }
        }
        return false
    }

    // Normalize legacy trait keys in Firestore after login
    private func normalizeTraitKeys(for uid: String, completion: @escaping () -> Void) {
        let users = Firestore.firestore().collection("users")
        users.document(uid).getDocument { snap, _ in
            guard let data = snap?.data(),
                  var traits = data["traits"] as? [String: Any] else {
                completion()
                return
            }

            var updates: [String: Any] = [:]
            // Map of legacy key -> new key
            let map: [(String, String)] = [
                ("Alcohol preference", "Alcohol"),
                ("Smoking preference", "Smoking"),
                ("Drugs preference", "Drugs"),
                ("Recreational use", "Drugs") // if you formerly stored under this label
            ]

            for (oldKey, newKey) in map {
                if let v = traits[oldKey], (traits[newKey] as? String)?.isEmpty ?? true {
                    updates["traits.\(newKey)"] = v
                }
                // schedule deletion of old key
                updates["traits.\(oldKey)"] = FieldValue.delete()
            }

            // Ensure "Sense of humor" exists key-wise if you had "Sense of Humor" capitalization differences
            if traits["Sense of humor"] == nil, let v = traits["Sense of Humor"] {
                updates["traits.Sense of humor"] = v
                updates["traits.Sense of Humor"] = FieldValue.delete()
            }

            guard !updates.isEmpty else {
                completion()
                return
            }

            users.document(uid).updateData(updates) { _ in
                completion()
            }
        }
    }
}

@ViewBuilder
fileprivate func sectionLabel(_ text: String) -> some View {
    Text(text)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textCase(.uppercase)
}

@ViewBuilder
fileprivate func fieldRow<Content: View>(icon: String, placeholder: String, @ViewBuilder content: () -> Content) -> some View {
    HStack(spacing: 10) {
        Image(systemName: icon)
            .foregroundStyle(.secondary)
            .frame(width: 18)
        content()
    }
    .padding(12)
    .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white)
    )
    .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.black.opacity(0.08), lineWidth: 1)
    )
}
