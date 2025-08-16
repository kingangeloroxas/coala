import SwiftUI
import PhotosUI
import AVKit

// MARK: - Message model

enum MessageKind {
    case text(String)
    case image(UIImage)
    case video(URL)
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let senderID: UUID?
    let timestamp: Date
    let isSystem: Bool
    let kind: MessageKind

    init(senderID: UUID?, text: String, timestamp: Date = Date(), isSystem: Bool = false) {
        self.senderID = senderID
        self.timestamp = timestamp
        self.isSystem = isSystem
        self.kind = .text(text)
    }

    init(senderID: UUID?, image: UIImage, timestamp: Date = Date()) {
        self.senderID = senderID
        self.timestamp = timestamp
        self.isSystem = false
        self.kind = .image(image)
    }

    init(senderID: UUID?, videoURL: URL, timestamp: Date = Date()) {
        self.senderID = senderID
        self.timestamp = timestamp
        self.isSystem = false
        self.kind = .video(videoURL)
    }
}

// MARK: - Chat View

struct ChatView: View {
    @EnvironmentObject var appState: AppState

    // Chat state
    @State private var messages: [ChatMessage] = []
    @State private var draft: String = ""
    @State private var hasPostedWelcome = false
    @FocusState private var inputFocused: Bool

    // Lightweight plan state (local; safe placeholders)
    @State private var planPlace: String? = nil
    @State private var planDate: Date? = nil

    // Media picking
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var isLoadingMedia = false
    @State private var mediaLoadError: String? = nil

    // Top Branch (leader) — random per session
    @State private var topBranchID: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "chat", onBack: { appState.goBack() })

            // Plan summary at top
            planSummaryBar()
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { msg in
                            if msg.isSystem {
                                systemRow(msg)
                                    .id(msg.id)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 2)
                            } else {
                                messageRow(msg)
                                    .id(msg.id)
                                    .padding(.horizontal, 12)
                            }
                        }

                        if isLoadingMedia {
                            HStack {
                                ProgressView()
                                Text("Loading media…")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                        }

                        if let err = mediaLoadError {
                            Text(err)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding(.vertical, 6)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .modifier(ScrollToBottomOnChange(count: messages.count, lastID: messages.last?.id, proxy: proxy))
            }

            // Input bar
            HStack(spacing: 10) {
                // Media button
                PhotosPicker(
                    selection: $pickerItem,
                    matching: .any(of: [.images, .videos]),
                    photoLibrary: .shared()
                ) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                }

                TextField("Message", text: $draft, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(false)
                    .focused($inputFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

                Button(action: sendText) {
                    Text("Send")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(draft.trimmed.isEmpty ? Color.gray.opacity(0.35) : Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(draft.trimmed.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            assignTopBranchIfNeeded()
            seedIfNeeded()
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let item = newItem else { return }
            Task { await handlePicked(item) }
        }
    }

    // MARK: - Plan summary bar

    private func planSummaryBar() -> some View {
        let activity = appState.selectedActivity ?? "activity"
        let place = planPlace ?? (appState.userCity.isEmpty ? "place" : appState.userCity)
        let timeText = planDate.map { Self.planTimeFormatter.string(from: $0) } ?? "time/day"

        return HStack(spacing: 8) {
            Label(activity, systemImage: "figure.2.and.child.holdinghands")
            dot()
            Label(place, systemImage: "mappin.and.ellipse")
            dot()
            Label(timeText, systemImage: "clock")
        }
        .font(.subheadline)
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .accessibilityLabel("Plan summary: \(activity), \(place), \(timeText)")
    }

    private func dot() -> some View {
        Circle().fill(Color.secondary.opacity(0.6))
            .frame(width: 4, height: 4)
    }

    // MARK: - Rows

    private func messageRow(_ msg: ChatMessage) -> some View {
        let isMe = (msg.senderID == appState.currentUser.id)

        return HStack(alignment: .bottom, spacing: 8) {
            if isMe { Spacer(minLength: 40) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 6) {
                switch msg.kind {
                case .text(let text):
                    Text(text)
                        .font(.body)
                        .foregroundColor(isMe ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isMe ? Color.blue : Color(.secondarySystemBackground))
                        )
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.72,
                               alignment: isMe ? .trailing : .leading)

                case .image(let image):
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
                        )

                case .video(let url):
                    VideoBubble(url: url)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.72)
                }

                Text(Self.timeString(msg.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(isMe ? .trailing : .leading, 4)
            }

            if !isMe { Spacer(minLength: 40) }
        }
        .transition(.move(edge: isMe ? .trailing : .leading).combined(with: .opacity))
    }

    private func systemRow(_ msg: ChatMessage) -> some View {
        VStack(spacing: 4) {
            if case .text(let text) = msg.kind {
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            Text(Self.timeString(msg.timestamp))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    // MARK: - Actions

    private func sendText() {
        let text = draft.trimmed
        guard !text.isEmpty else { return }
        draft = ""
        messages.append(ChatMessage(senderID: appState.currentUser.id, text: text))
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func handlePicked(_ item: PhotosPickerItem) async {
        mediaLoadError = nil
        isLoadingMedia = true
        defer { isLoadingMedia = false; pickerItem = nil }

        // Try to detect if it’s an image first
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            messages.append(ChatMessage(senderID: appState.currentUser.id, image: uiImage))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }

        // Otherwise, try a video URL
        do {
            if let url = try await item.loadTransferable(type: URL.self) {
                // Copy to a safe, unique temp location so it persists
                let tempURL = try persistVideo(at: url)
                messages.append(ChatMessage(senderID: appState.currentUser.id, videoURL: tempURL))
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                return
            }
        } catch {
            // fallthrough to error below
        }

        mediaLoadError = "Couldn’t load that photo or video. Try a different file."
    }

    private func persistVideo(at sourceURL: URL) throws -> URL {
        let fm = FileManager.default
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let dest = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("chatvid-\(UUID().uuidString).\(ext)")
        if fm.fileExists(atPath: dest.path) {
            try? fm.removeItem(at: dest)
        }
        try fm.copyItem(at: sourceURL, to: dest)
        return dest
    }

    // MARK: - Seeding / Top Branch

    private func assignTopBranchIfNeeded() {
        guard topBranchID == nil else { return }
        let group = appState.matchedUsers
        if let randomLeader = (group.isEmpty ? [appState.currentUser] : group).randomElement() {
            topBranchID = randomLeader.id
        }
    }

    private func seedIfNeeded() {
        guard !hasPostedWelcome else { return }
        hasPostedWelcome = true

        let names = appState.matchedUsers
            .map { displayNameWithLeaf(for: $0) }
            .joined(separator: " • ")

        let activity = appState.selectedActivity ?? "your plan"
        messages.append(ChatMessage(senderID: nil, text: "Welcome to your match! 🎉 You’re planning \(activity).", isSystem: true))
        if !names.isEmpty {
            messages.append(ChatMessage(senderID: nil, text: "Group: \(names)", isSystem: true))
        }

        // Announce Top Branch (leader)
        if let leaderID = topBranchID,
           let leaderUser = (appState.matchedUsers + [appState.currentUser]).first(where: { $0.id == leaderID }) {
            let leaderName = displayName(for: leaderUser)
            messages.append(ChatMessage(
                senderID: nil,
                text: "🍃 Top Branch: \(leaderName) is the group leader. They’ll make the final call on the activity's time & place.",
                isSystem: true
            ))
        }
    }

    private func isTopBranch(_ user: User) -> Bool {
        user.id == topBranchID
    }

    private func displayName(for user: User) -> String {
        user.id == appState.currentUser.id ? "You" : (user.name.isEmpty ? "Friend" : user.name)
    }

    private func displayNameWithLeaf(for user: User) -> String {
        let base = displayName(for: user)
        return isTopBranch(user) ? "\(base) 🍃" : base
    }

    // MARK: - Formatters

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df
    }()

    private static func timeString(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static let planTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("EEE h:mm a")
        return df
    }()
}

// MARK: - Video bubble

private struct VideoBubble: View {
    let url: URL
    @State private var player: AVPlayer? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                    .onDisappear { player.pause() }
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Preparing video…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    )
                    .frame(height: 160)
            }
        }
        .onAppear { player = AVPlayer(url: url) }
    }
}

// MARK: - Helpers

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// Handles iOS 17/16 onChange differences for scrolling to bottom.
private struct ScrollToBottomOnChange: ViewModifier {
    let count: Int
    let lastID: UUID?
    let proxy: ScrollViewProxy

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { _ in
                    Color.clear
                        .onChangeCompat(of: count) {
                            if let id = lastID {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(id, anchor: .bottom)
                                }
                            }
                        }
                }
            )
    }
}

private extension View {
    /// iOS 17 two-parameter `onChange` with a fallback for iOS 16.
    func onChangeCompat<T: Equatable>(of value: T, perform action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, *) {
            return self.onChange(of: value) { _, _ in action() }
        } else {
            return self.onChange(of: value) { _ in action() }
        }
    }
}

