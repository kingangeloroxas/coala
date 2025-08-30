import SwiftUI

enum UserTier { case regular, topLevel, premium }

struct HubView: View {
    @EnvironmentObject var appState: AppState
    @State private var showInfo: Bool = false
    @State private var infoMessage: String = ""

    // Tier selection (wire to AppState when available)
    @State private var tier: UserTier = .regular
    private var chatCapacity: Int { tier == .premium ? 5 : (tier == .topLevel ? 3 : 2) }

    // Temporary demo data – replace with your appState source when ready
    @State private var chats: [ChatSummary] = [
        .init(id: UUID(), activity: "restaurant", emoji: "🍽️", hasVenue: true,  hasLocation: true,  hasTime: false, unread: 2, preview: "Table for 6 at 7pm?", isTopBranch: true),
        .init(id: UUID(), activity: "pickleball", emoji: "🎾", hasVenue: false, hasLocation: true,  hasTime: true,  unread: 0, preview: "Court 3 is open", isTopBranch: false),
        .init(id: UUID(), activity: "karaoke",    emoji: "🎤", hasVenue: false, hasLocation: false, hasTime: false, unread: 5, preview: "Which songs tonight?", isTopBranch: false),
        .init(id: UUID(), activity: "brunch",     emoji: "🥞", hasVenue: true,  hasLocation: true,  hasTime: true,  unread: 1, preview: "Cafe Coala at 11?", isTopBranch: true)
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemBackground).ignoresSafeArea()

                VStack(spacing: 16) {
                    // Title centered, profile button leading
                    ZStack {
                        Text("Coala Hub")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(red: 0.09, green: 0.27, blue: 0.55))
                            .frame(maxWidth: .infinity, alignment: .center)

                        HStack {
                            NavigationLink {
                                ProfileView()
                                    .environmentObject(appState)
                            } label: {
                                Text("Profile")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(.secondarySystemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())

                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)

                    // Active chats
                    if !chats.isEmpty {
                        ActiveChatsHeader()
                            .padding(.top, 12)
                        ActiveChatsCarousel(chats: chats, chatCapacity: chatCapacity) { chat in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            // appState.openChat(chat.id)
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer()
                }
                .padding(.top, 32)
            }
            // Bottom inset: big activity button + dock
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 28) {
                    ZStack(alignment: .topTrailing) {
                        ActivityGraphicButton(
                            imageName: "activity_button",
                            accessibilityLabel: "Go to Activities"
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            appState.goToActivity()
                        }
                        .padding(.horizontal, 16)
                    }

                    ZStack {
                        HubDock()
                            .environmentObject(appState)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 66)
                }
                .padding(.bottom, 8)
            }
            .navigationBarBackButtonHidden(true)
            .alert("About Coala", isPresented: $showInfo) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text(infoMessage)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Models & Subviews

struct ChatSummary: Identifiable, Equatable {
    let id: UUID
    let activity: String
    let emoji: String
    var hasVenue: Bool
    var hasLocation: Bool
    var hasTime: Bool
    var unread: Int
    var preview: String
    var isTopBranch: Bool
}

private struct ActiveChatsHeader: View {
    var body: some View {
        HStack {
            Text("Active Chats")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.09, green: 0.27, blue: 0.55))
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

private struct ActiveChatsCarousel: View {
    let chats: [ChatSummary]
    let chatCapacity: Int
    var onTap: (ChatSummary) -> Void

    var body: some View {
        let capacity = min(5, max(1, chatCapacity))
        let displayed = Array(chats.prefix(capacity))
        let placeholders = max(0, capacity - displayed.count)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(displayed) { chat in
                    ActiveChatBubble(chat: chat)
                        .onTapGesture { onTap(chat) }
                }
                if placeholders > 0 {
                    ForEach(0..<placeholders, id: \.self) { _ in
                        PlaceholderChatBubble()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct ActiveChatBubble: View {
    let chat: ChatSummary

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(LinearGradient(colors: [Color.white, Color(red: 0.87, green: 0.94, blue: 1.0)], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text(chat.emoji)
                            .font(.system(size: 28))
                    )
            }

            Text(chat.activity.capitalized)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 72)

            Text(chat.preview)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 120, alignment: .center)

            ChatChecklist(hasVenue: chat.hasVenue, hasLocation: chat.hasLocation, hasTime: chat.hasTime)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            if chat.isTopBranch {
                HStack(spacing: 0) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.green)
                        .padding(6)
                        .background(Circle().fill(Color.green.opacity(0.18)))
                }
                .padding(8)
            }
        }
        .overlay(alignment: .topTrailing) {
            if chat.unread > 0 {
                Text("\(min(chat.unread, 99))")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
                    .padding(8)
            }
        }
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

private struct PlaceholderChatBubble: View {
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color(.tertiarySystemFill))
                .frame(width: 64, height: 64)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 72, height: 12)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule().fill(Color(.tertiarySystemFill)).frame(width: 36, height: 18)
                }
            }
            .frame(width: 120)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .opacity(0.6)
    }
}

private struct ChatChecklist: View {
    var hasVenue: Bool
    var hasLocation: Bool
    var hasTime: Bool

    var body: some View {
        HStack(spacing: 8) {
            ChecklistPill(isDone: hasVenue, label: "venue")
            ChecklistPill(isDone: hasLocation, label: "location")
            ChecklistPill(isDone: hasTime, label: "time")
        }
        .frame(width: 120)
    }
}

private struct ChecklistPill: View {
    var isDone: Bool
    var label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isDone ? Color.blue : Color.gray.opacity(0.6))
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isDone ? Color.blue : Color.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(
                isDone ? Color.blue.opacity(0.10) : Color.gray.opacity(0.10)
            )
        )
    }
}

// Corner helper (only include once project-wide)
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
