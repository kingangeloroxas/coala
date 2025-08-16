import SwiftUI

struct MatchingView: View {
    @EnvironmentObject var appState: AppState

    // Local state
    @State private var isMatching = false
    @State private var matchedGroup: [User] = []

    // ----------------------------------------------------------------------
    // COMPATIBILITY: accept old call sites that passed 4 strings/ints.
    // We ignore these; they only exist so previews/old code still compile.
    // ----------------------------------------------------------------------
    init() {}
    init(groupSize: Int, matchedUserNames: String, vibe: String, status: String) { }

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "matching", onBack: { appState.goBack() })

            // Qualify SwiftUI.Group to avoid collision with any model named `Group`
            SwiftUI.Group {
                if isMatching {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Finding your group…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if matchedGroup.isEmpty {
                    VStack(spacing: 12) {
                        Text("Ready to match?")
                            .font(.headline)
                        Text("We’ll find a group you'll vibe with!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("Your group") {
                            ForEach(matchedGroup, id: \.id) { u in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        // Name
                                        Text(u.name.isEmpty ? "Friend" : u.name)
                                            .font(.headline)

                                        // Details: MBTI • Age • City
                                        HStack(spacing: 6) {
                                            if !u.mbti.isEmpty {
                                                Text(u.mbti)
                                            }
                                            Text("• \(u.age)")
                                            if let city = u.city, !city.isEmpty {
                                                Text("• \(city)")
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }

            Button(action: primaryAction) {
                Text(matchedGroup.isEmpty ? "Match Me!" : "Open chat")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Actions

    private func primaryAction() {
        if matchedGroup.isEmpty {
            runMatching()
        } else {
            appState.matchedUsers = matchedGroup
            appState.currentScreen = .chat
        }
    }

    private func runMatching() {
        isMatching = true
        matchedGroup = []

        let targetSize = appState.selectedGroupSize ?? 4

        // Make sure "me" carries the latest city/activity before matching.
        var me = appState.currentUser
        if (me.city?.isEmpty ?? true), !appState.userCity.isEmpty {
            me.city = appState.userCity
        }
        if (me.activity?.isEmpty ?? true), let act = appState.selectedActivity, !act.isEmpty {
            me.activity = act
        }

        // Start with your synthetic/sample users. Replace with your real pool when available.
        var pool = SampleData.users
        if !pool.contains(where: { $0.id == me.id }) {
            pool.insert(me, at: 0)
        }

        // Simulate a short "searching…" delay, then use the matcher.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let group = Matcher.matchGroup(
                me: me,
                pool: pool,
                desiredSize: targetSize,
                selectedActivity: appState.selectedActivity
            )
            matchedGroup = group
            isMatching = false
        }
    }
}

#if DEBUG
#Preview {
    MatchingView()
        .environmentObject(AppState())
}
#endif

