import SwiftUI
import PhotosUI
import AVKit
import MapKit
import Contacts
import CoreLocation
import Combine

#if canImport(UIKit)
import UIKit
#endif

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool { (self ?? "").isEmpty }
}

// MARK: - Message model

enum MessageKind { case text(String), image(UIImage), video(URL) }

struct ChatMessage: Identifiable {
    let id = UUID()
    let senderID: UUID?
    let timestamp: Date
    let isSystem: Bool
    let kind: MessageKind

    init(senderID: UUID?, text: String, timestamp: Date = Date(), isSystem: Bool = false) {
        self.senderID = senderID; self.timestamp = timestamp; self.isSystem = isSystem; self.kind = .text(text)
    }
    init(senderID: UUID?, image: UIImage, timestamp: Date = Date()) {
        self.senderID = senderID; self.timestamp = timestamp; self.isSystem = false; self.kind = .image(image)
    }
    init(senderID: UUID?, videoURL: URL, timestamp: Date = Date()) {
        self.senderID = senderID; self.timestamp = timestamp; self.isSystem = false; self.kind = .video(videoURL)
    }
}

// Rows rendered in the messages list (supports separators and markers)
enum ChatRow: Identifiable {
    case daySeparator(Date)
    case newMarker
    case message(ChatMessage)

    var id: String {
        switch self {
        case .daySeparator(let d): return "sep-\(Int(d.timeIntervalSince1970))"
        case .newMarker: return "marker-new"
        case .message(let m): return m.id.uuidString
        }
    }
}

// MARK: - Chat View

struct ChatView: View {
    @EnvironmentObject var appState: AppState

    // Chat state
    @State private var messages: [ChatMessage] = []
    @State private var draft: String = ""
    @State private var hasPostedWelcome = false

    // Planning state
    @State private var planVenue: String? = nil
    @State private var planVenueAddress: String? = nil
    @State private var planDate: Date? = nil
    @State private var planTime: Date? = nil

    // Media picking
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var isLoadingMedia = false
    @State private var mediaLoadError: String? = nil

    // Plan completion animation state
    @State private var planJustCompleted = false
    @State private var planLockedGold   = false

    // Commit flags: show green checks only after user finishes editing / confirms
    @State private var venueCommitted = false
    @State private var dateCommitted  = false
    @State private var timeCommitted  = false

    // Leader (Top Branch)
    @State private var topBranchID: UUID? = nil

    // Inline venue focus
    @FocusState private var venueFieldFocused: Bool

    // Sheets (date/time)
    @State private var showDateSheet  = false
    @State private var showTimeSheet  = false
    @State private var showVenueSearch = false

    // Menu state
    @State private var showMembersSheet = false
    @State private var showLeaveConfirm = false
    @State private var showTopBranchInfo = false
    @State private var showConfirmActivity = false

    // Message UI state
    @State private var lastReadAt: Date = Date()           // where to place the "New messages" marker
    @State private var reactions: [UUID: [String: Int]] = [:] // message.id -> {emoji: count}
    @State private var pendingReply: ChatMessage? = nil     // quoted message
    @State private var showTypingIndicator: Bool = false    // peers typing
    @State private var listRevealX: CGFloat = 0 // global left-drag to reveal all timestamps
    @State private var scrollToBottomTick: Int = 0

    // Label width so "@" and "on" align
    private let labelWidth: CGFloat = 28

    // MARK: - Auto prompts per activity
    private let autoPrompts: [String: (question: String, tip: String)] = [
        "hiking": (
            "What kind of hike sounds fun for everyone—scenic lookout, shaded forest loop, or something more challenging?",
            "Check trail length/elevation and daylight. Pick a well‑rated trailhead with clear parking and share a pin. Bring water and a lightweight layer."
        ),
        "pool": (
            "Are we thinking a casual game night at a billiards bar or somewhere quieter to chat while we play?",
            "Verify age policy/IDs if it’s a bar. Choose a spot with multiple tables and decent lighting; confirm wait times or call ahead for availability."
        ),
        "movie": (
            "What vibe are we going for—blockbuster, indie, or a comfy dine‑in theater?",
            "Pick a showtime near everyone. Aim for center/back row seating. Meet 15–20 minutes early for tickets and snacks."
        ),
        "pickleball": (
            "Open‑play or reserve a court? Any preference for indoor vs. outdoor?",
            "Reserve a court if possible. Bring an extra paddle and confirm the park’s lighting if it’s evening. Hydration + non‑marking shoes."
        ),
        "karaoke": (
            "Private room or open mic? Any must‑sing songs for the queue?",
            "Book a room in advance for groups. Check per‑person pricing and confirm ID requirements. Share the exact address/parking."
        ),
        "coffee": (
            "Cozy café to talk, or a spot with outdoor seating and good people‑watching?",
            "Choose a well‑lit café with seating for the group. Verify closing time and parking. Consider a quieter hour to actually hear each other."
        ),
        "golf": (
            "Driving range, mini‑par 3, or a full 9?",
            "Ranges often don’t need tee times; courses do. Check dress code and rental availability; bring sunscreen and water."
        ),
        "museum": (
            "Art, science, or history—what sounds most interesting this week?",
            "Confirm hours and any ticketed exhibits. Pick a clear meeting entrance; large museums can have multiple. Backpacks may need coat check."
        ),
        "dessert": (
            "Ice cream, pastries, or a late‑night dessert bar? Any dietary preferences to keep in mind?",
            "Find a shop with seating and reasonable lines. Share a meet‑up pin; check closing time so we’re not rushed."
        ),
        "boba": (
            "Classic milk tea, fruit tea, or something adventurous?",
            "Peak hours can be crowded—consider off‑peak. Verify parking or transit, and share a meet‑up landmark nearby."
        ),
        "brunch": (
            "Sweet, savory, or bottomless vibes?",
            "Popular spots fill up—put your name on the waitlist or book if available. Check split‑bill options and any time limits."
        ),
        "surfing": (
            "Beginner beach with soft waves or a spot for intermediates?",
            "Check surf/weather + lifeguard hours. Bring sunscreen, water, and confirm board rentals/wetsuit sizes at the beach."
        ),
        "pumpkin patch": (
            "Casual stroll for photos or the full hayride + maze experience?",
            "Look up tickets/entry times. Wear closed‑toe shoes and plan parking—fields can be muddy after rain."
        ),
        "theme park": (
            "Thrill rides first or a slower wander with shows and snacks?",
            "Buy tickets ahead and pick a meeting gate. Set a loose schedule + group chat share location in case of crowds."
        ),
        "board game": (
            "Cafe with a library or bring‑your‑own at someone’s place?",
            "Confirm table availability/time limits at cafes. If BYO, pick easy teach games and agree on a time window + snacks."
        )
    ]

    private func postAutoPrompts(for activity: String) {
        let key = normalizeActivity(activity)
        guard let pair = autoPrompts[key] else { return }
        messages.append(ChatMessage(senderID: nil, text: pair.question, isSystem: true))
    }

    // Gold/sheens should trigger only when all three fields are explicitly committed (user confirmed),
    // not merely when they contain any value.
    private var isPlanCommittedComplete: Bool {
        venueCommitted && dateCommitted && timeCommitted
    }

    private func buildRows(from messages: [ChatMessage]) -> [ChatRow] {
        var out: [ChatRow] = []
        var lastDay: DateComponents?
        let cal = Calendar.current
        var insertedNewMarker = false
        for m in messages.sorted(by: { $0.timestamp < $1.timestamp }) {
            let comps = cal.dateComponents([.year, .month, .day], from: m.timestamp)
            if comps != lastDay {
                lastDay = comps
                if let d = cal.date(from: comps) { out.append(.daySeparator(d)) }
            }
            if !insertedNewMarker && m.timestamp > lastReadAt {
                out.append(.newMarker)
                insertedNewMarker = true
            }
            out.append(.message(m))
        }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: centered Activity button + venue row
            ActivityTopBarView(
                activity: appState.selectedActivity ?? "Activity",
                emoji: activityEmoji(for: appState.selectedActivity) ?? "🎉",
                planVenue: $planVenue,
                planVenueAddress: $planVenueAddress,
                venueFieldFocused: $venueFieldFocused,
                committedVenue: $venueCommitted,
                onOpenVenueSearch: { showVenueSearch = true },
                onTapActivity: { appState.goToActivity() },
                onShowMembers: { showMembersSheet = true },
                onShowTopBranch: { showTopBranchInfo = true },
                onConfirmActivity: { showConfirmActivity = true },
                onLeaveGroup: { showLeaveConfirm = true },
                labelWidth: labelWidth,
                gold: planLockedGold,
                sheen: planJustCompleted,
                onHome: { appState.goToHub() }
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // Completion bar: "on" + Date (fixed) + Time (fixed)
            CompletionBarView(
                planDate: planDate,
                planTime: planTime,
                onTapDate:  { showDateSheet = true },
                onTapTime:  { showTimeSheet = true },
                onClearDate: { planDate = nil; dateCommitted = false },
                onClearTime: { planTime = nil; timeCommitted = false },
                labelWidth: labelWidth,
                gold: planLockedGold,
                sheen: planJustCompleted,
                dateCommitted: dateCommitted,
                timeCommitted: timeCommitted
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // Messages
            MessagesList(
                rows: buildRows(from: messages),
                currentUserID: appState.currentUser.id,
                isLoadingMedia: isLoadingMedia,
                mediaLoadError: mediaLoadError,
                nameFor: { id in firstName(for: id) },
                reactions: $reactions,
                onReact: { id, emoji in
                    var map = reactions[id] ?? [:]
                    map[emoji] = (map[emoji] ?? 0) + 1
                    reactions[id] = map
                },
                onReply: { msg in pendingReply = msg },
                showTyping: showTypingIndicator,
                revealX: $listRevealX,
                scrollToBottomTick: scrollToBottomTick
            )

            // Reply preview
            if let reply = pendingReply {
                HStack(spacing: 8) {
                    Rectangle().fill(Color.blue).frame(width: 3).cornerRadius(1.5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replying to \(firstName(for: reply.senderID))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if case let .text(t) = reply.kind {
                            Text(t).font(.caption2).lineLimit(1).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        pendingReply = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

        }
        .contentShape(Rectangle())
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            InputBar(
                draft: $draft,
                pickerItem: $pickerItem,
                onSend: sendText,
                onTapTextField: { scrollToBottomTick += 1 },
                onFocusChanged: { focused in
                    if focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { scrollToBottomTick += 1 }
                    }
                }
            )
        }
        .onAppear { assignTopBranchIfNeeded(); seedIfNeeded(); lastReadAt = Date() }
        .onChange(of: pickerItem) { _, newItem in
            guard let item = newItem else { return }
            Task { await handlePicked(item) }
        }
        .onChange(of: draft) { _, _ in
            // While typing, keep the list pinned to the latest message (iMessage behavior)
            scrollToBottomTick += 1
        }
        .onChange(of: isPlanCommittedComplete) { _, nowCommittedComplete in
            if nowCommittedComplete {
                // Lock gold immediately and shimmer for ~3 seconds.
                if !planLockedGold { planLockedGold = true }
                planJustCompleted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    // stop shimmer after 3s
                    planJustCompleted = false
                }
            } else {
                // If any committed flag turns off, revert immediately.
                planJustCompleted = false
                planLockedGold = false
            }
        }
        // Members sheet
        .sheet(isPresented: $showMembersSheet) {
            MembersSheet(users: (appState.matchedUsers + [appState.currentUser]))
        }
        // Top Branch info
        .alert("Top Branch", isPresented: $showTopBranchInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(firstName(for: topBranchID)) is the group leader.")
        }
        // Confirm activity
        .alert("Confirm activity?", isPresented: $showConfirmActivity) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm") {
                if let act = appState.selectedActivity { postAutoPrompts(for: act) }
            }
        } message: {
            Text(appState.selectedActivity ?? "Activity")
        }
        // Leave group confirm
        .alert("Leave this group?", isPresented: $showLeaveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Leave Group", role: .destructive) {
                // Basic leave: clear match and go back to previous screen
                appState.matchedUsers = []
                appState.goBack()
            }
        } message: {
            Text("You’ll be removed from this chat. You can always match again later.")
        }
        // Sheets (date & time)
        .sheet(isPresented: $showDateSheet)  {
            DateSheet(
                planDate: $planDate,
                onConfirm: { dateCommitted = (planDate != nil) },
                onCancel:  { /* leave as-is */ }
            )
        }
        .sheet(isPresented: $showTimeSheet)  {
            TimeSheet(
                planTime: $planTime,
                defaultTime: defaultNearestHalfHour(from: Date()),
                onConfirm: { timeCommitted = (planTime != nil) },
                onCancel:  { /* leave as-is */ }
            )
        }
        .sheet(isPresented: $showVenueSearch) {
            VenueSearchSheet { name, addr in
                planVenue = name
                planVenueAddress = addr
                venueCommitted = true
            }
        }
    }

    // MARK: - Small subviews

private struct ActivityTopBarView: View {
    let activity: String
    let emoji: String
    @Binding var planVenue: String?
    @Binding var planVenueAddress: String?
    var venueFieldFocused: FocusState<Bool>.Binding
    @Binding var committedVenue: Bool
    let onOpenVenueSearch: () -> Void
    let onTapActivity: () -> Void
    let onShowMembers: () -> Void
    let onShowTopBranch: () -> Void
    let onConfirmActivity: () -> Void
    let onLeaveGroup: () -> Void
    let labelWidth: CGFloat
    let gold: Bool
    let sheen: Bool
    let onHome: () -> Void

    @State private var suggestionsActive: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            // Row 1: minimalist blue home button (leading), centered Activity button, trailing menu
            ZStack {
                // Layout: HStack fills width, home button leading, activity center, menu trailing
                HStack {
                    // Leading home button
                    Button(action: onHome) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                    // Centered activity button
                    Button(action: onTapActivity) {
                        HStack(spacing: 8) {
                            Text(activity).font(.headline)
                            Text(emoji).font(.system(size: 18))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    // Trailing menu button
                    Menu {
                        // 1) Group members
                        Button { onShowMembers() } label: {
                            Label("Group members", systemImage: "person.2.fill")
                        }
                        // 2) Top Branch
                        Button { onShowTopBranch() } label: {
                            Label("Top Branch", systemImage: "leaf.fill")
                        }
                        // 3) Confirm activity
                        Button { onConfirmActivity() } label: {
                            Label("Confirm activity", systemImage: "checkmark.seal")
                        }
                        // 4) Leave group
                        Button(role: .destructive) { onLeaveGroup() } label: {
                            Label("Leave group", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 7.5) // align with checkmark circles below
                            .contentShape(Rectangle())
                    }
                }
            }
            .frame(height: 44)
            .opacity(1)
            .clipped()

            // Row 2: Venue row (outer container matches Date/Time)
            HStack(spacing: 8) {
                Text("@")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(width: labelWidth, alignment: .leading)

                // Venue pill + outside checkmark
                HStack(spacing: 6) {
                    VenueInlineField(
                        planVenue: $planVenue,
                        planVenueAddress: $planVenueAddress,
                        committedVenue: $committedVenue,
                        venueFieldFocused: venueFieldFocused,
                        gold: gold,
                        sheen: sheen
                    )
                    Button {
                        if !planVenue.isNilOrEmpty {
                            planVenue = nil
                            planVenueAddress = nil
                            committedVenue = false
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        Image(systemName: committedVenue ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(committedVenue ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(planVenue.isNilOrEmpty ? "Venue not set" : "Clear venue")
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .zIndex(suggestionsActive ? 1000 : 0)
        .onPreferenceChange(SuggestionsActiveKey.self) { suggestionsActive = $0 }
    }
}

    private struct CompletionBarView: View {
        let planDate: Date?
        let planTime: Date?
        let onTapDate:  () -> Void
        let onTapTime:  () -> Void
        let onClearDate: () -> Void
        let onClearTime: () -> Void
        let labelWidth: CGFloat
        let gold: Bool
        let sheen: Bool
        let dateCommitted: Bool
        let timeCommitted: Bool

        var body: some View {
            HStack(spacing: 10) {
                Text("on")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(width: labelWidth, alignment: .leading)

                HStack(spacing: 6) {
                    CompletionFieldNoIcon(
                        title: planDate.map { ChatView.fullPrettyDate($0) } ?? "Date",
                        placeholder: "Date",
                        style: planDate == nil ? .empty : .filled,
                        tap: onTapDate,
                        centered: false,
                        gold: gold,
                        sheen: sheen
                    )
                    .padding(.horizontal, -2) // Reduce horizontal padding by 2 (14 -> 12)
                    .frame(minWidth: 150, maxWidth: .infinity, minHeight: 37, maxHeight: 37)

                    Button {
                        if planDate != nil {
                            onClearDate()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        Image(systemName: dateCommitted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(dateCommitted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(planDate == nil ? "Date not set" : "Clear date")
                }

                HStack(spacing: 6) {
                    CompletionFieldNoIcon(
                        title: planTime.map { ChatView.timeFormatter.string(from: $0) } ?? "Time",
                        placeholder: "Time",
                        style: planTime == nil ? .empty : .filled,
                        tap: onTapTime,
                        centered: false,
                        gold: gold,
                        sheen: sheen
                    )
                    .frame(width: 92, height: 37)

                    Button {
                        if planTime != nil {
                            onClearTime()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        Image(systemName: timeCommitted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(timeCommitted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(planTime == nil ? "Time not set" : "Clear time")
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private struct MessagesList: View {
        let rows: [ChatRow]
        let currentUserID: UUID
        let isLoadingMedia: Bool
        let mediaLoadError: String?
        let nameFor: (UUID?) -> String
        @Binding var reactions: [UUID: [String: Int]]
        let onReact: (UUID, String) -> Void
        let onReply: (ChatMessage) -> Void
        let showTyping: Bool
        @Binding var revealX: CGFloat
        let scrollToBottomTick: Int

        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                            switch row {
                            case .daySeparator(let d):
                                DaySeparator(date: d)
                                    .id("sep-\(Int(d.timeIntervalSince1970))")
                                    .padding(.top, 4)
                            case .newMarker:
                                NewMessagesMarker()
                                    .id("marker-new")
                            case .message(let msg):
                                let showNameFlag: Bool = {
                                    var k = idx - 1
                                    while k >= 0 {
                                        switch rows[k] {
                                        case .message(let prev):
                                            return prev.senderID != msg.senderID
                                        case .daySeparator, .newMarker:
                                            break
                                        }
                                        k -= 1
                                    }
                                    return true
                                }()
                                VStack(spacing: 4) {
                                    ChatViewMessageRow(msg: msg, currentUserID: currentUserID, nameFor: nameFor, revealX: $revealX, showName: showNameFlag)
                                        .id(msg.id)
                                        .padding(.horizontal, msg.isSystem ? 16 : 12)
                                        .padding(.top, msg.isSystem ? 2 : 0)
                                        .contextMenu {
                                            if case .text = msg.kind {
                                                Button { onReply(msg) } label: { Label("Reply", systemImage: "arrowshape.turn.up.left") }
                                            }
                                            Button { onReact(msg.id, "❤️") } label: { Label("Love", systemImage: "heart.fill") }
                                            Button { onReact(msg.id, "😂") } label: { Label("Laugh", systemImage: "face.smiling") }
                                            Button { onReact(msg.id, "👍") } label: { Label("Like", systemImage: "hand.thumbsup.fill") }
                                            Button { onReact(msg.id, "🔥") } label: { Label("Fire", systemImage: "flame.fill") }
                                        }

                                    if let map = reactions[msg.id], !map.isEmpty {
                                        HStack(spacing: 6) {
                                            ForEach(map.keys.sorted(), id: \.self) { key in
                                                if let count = map[key] {
                                                    HStack(spacing: 4) {
                                                        Text(key)
                                                        Text("\(count)").font(.caption2)
                                                    }
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(Capsule().fill(Color(.secondarySystemBackground)))
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                        }

                        if isLoadingMedia {
                            HStack { ProgressView(); Text("Loading media…").font(.footnote).foregroundStyle(.secondary) }
                                .padding(.vertical, 8)
                        }
                        if let err = mediaLoadError {
                            Text(err).font(.footnote).foregroundColor(.red).padding(.vertical, 6)
                        }
                        if showTyping {
                            TypingIndicatorView()
                        }
                    }
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.never)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            let dx = value.translation.width
                            let dy = value.translation.height
                            // Only act on predominantly horizontal left-drags; let vertical scrolling pass through.
                            guard abs(dx) > abs(dy) else { return }
                            if dx < 0 {
                                let maxReveal: CGFloat = 96
                                revealX = max(-maxReveal, dx)
                            } else {
                                revealX = 0
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.25)) {
                                revealX = 0
                            }
                        }
                )
                .modifier(ScrollToBottomOnChange(count: rows.count, lastRowID: rows.last?.id, proxy: proxy))
                #if canImport(UIKit)
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { _ in
                    if let last = rows.last { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    if let last = rows.last { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    if let last = rows.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                #endif
                .onChange(of: scrollToBottomTick) { _, _ in
                    if let last = rows.last { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
        }
    }


    private struct DaySeparator: View {
        let date: Date
        var body: some View {
            Text(ChatView.fullPrettyDate(date))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(.secondarySystemBackground)))
                .frame(maxWidth: .infinity)
        }
    }

    private struct NewMessagesMarker: View {
        var body: some View {
            HStack(alignment: .center, spacing: 8) {
                Rectangle().fill(Color.blue.opacity(0.2)).frame(height: 1)
                Text("New messages")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                Rectangle().fill(Color.blue.opacity(0.2)).frame(height: 1)
            }
            .padding(.horizontal, 12)
        }
    }

    private struct TypingIndicatorView: View {
        var body: some View {
            HStack(spacing: 6) {
                Circle().frame(width: 6, height: 6).foregroundStyle(.blue).opacity(0.7)
                Circle().frame(width: 6, height: 6).foregroundStyle(.blue).opacity(0.7)
                Circle().frame(width: 6, height: 6).foregroundStyle(.blue).opacity(0.7)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }

    private struct ChatViewMessageRow: View {
        let msg: ChatMessage
        let currentUserID: UUID
        let nameFor: (UUID?) -> String
        @Binding var revealX: CGFloat
        let showName: Bool

        var body: some View {
            // System messages (no drag-to-reveal time)
            if msg.isSystem {
                return AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        SystemMessageBubble(text: {
                            if case let .text(t) = msg.kind { return t } else { return "" }
                        }())
                        Spacer(minLength: 0) // allow full-width bubble
                    }
                )
            }

            // Regular messages with iMessage-style timestamp reveal on left drag
            let isMe = (msg.senderID == currentUserID)
            let first = nameFor(msg.senderID)
            let maxReveal: CGFloat = 96
            let progress = min(1, max(0, -revealX / maxReveal))

            return AnyView(
                ZStack(alignment: .trailing) {
                    // Trailing timestamp (reveals as you drag left)
                    Text(ChatView.timeString(msg.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 12)
                        .opacity(Double(progress))
                        .offset(x: 8 * (1 - progress))

                    // Foreground message row, shifted left as you drag
                    HStack(alignment: .bottom, spacing: 8) {
                        if isMe { Spacer(minLength: 40) }
                        VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                            // Name badge
                            if showName {
                                Text(first)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color(.secondarySystemBackground)))
                                    .alignmentGuide(.leading) { d in d[.leading] }
                            }

                            // Message bubble
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
                                        .resizable().scaledToFit()
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
                            }
                        }
                        if !isMe { Spacer(minLength: 40) }
                    }
                    .offset(x: revealX)
                    .transition(.move(edge: isMe ? .trailing : .leading).combined(with: .opacity))
                }
            )
        }
    }

    private struct SystemMessageBubble: View {
        let text: String
        var body: some View {
            // Fixed badge gutter creates identical spacing for every message,
            // independent of bubble line-wrapping or height.
            let badgeSize: CGFloat = 18
            let badgeGutter: CGFloat = 30     // fixed leading gutter width
            let badgeXInset: CGFloat = 4      // how much the badge overlaps the bubble
            let badgeYInset: CGFloat = 6

            HStack(alignment: .top, spacing: 0) {
                // Badge column with consistent width
                ZStack(alignment: .topLeading) {
                    SystemBadge()
                        .frame(width: badgeSize, height: badgeSize)
                        // Slight overlap towards the bubble for that tucked look
                        .offset(x: badgeXInset, y: badgeYInset)
                }
                .frame(width: badgeGutter)

                // Bubble + timestamp
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .layoutPriority(1)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )

                    Text(ChatView.timeString(Date()))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct SystemBadge: View {
        // Uses the asset named "coalabadge" (koala head only, no circle).
        // Falls back to an SF Symbol if the asset isn't present.
        private var badgeImage: Image {
            #if canImport(UIKit)
            if UIImage(named: "coalabadge") != nil { return Image("coalabadge") }
            #endif
            return Image(systemName: "face.smiling.fill")
        }

        var body: some View {
            badgeImage
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18) // badge size
                .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 1)
                .accessibilityLabel("System message")
        }
    }

    // MARK: - NonResigningTextField
    private struct NonResigningTextField: UIViewRepresentable {
        @Binding var text: String
        @Binding var isFirstResponder: Bool
        var placeholder: String
        var onReturn: () -> Void

        class Coordinator: NSObject, UITextFieldDelegate {
            var parent: NonResigningTextField
            init(_ parent: NonResigningTextField) { self.parent = parent }

            func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
                // When the user taps the field (or we programmatically focus it), mark as wanting focus.
                parent.isFirstResponder = true
                return true
            }

            func textFieldShouldReturn(_ textField: UITextField) -> Bool {
                parent.onReturn()
                // Prevent the keyboard from dismissing when pressing Return/Send.
                return false
            }

            @objc func editingChanged(_ textField: UITextField) {
                parent.text = textField.text ?? ""
            }

            func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
                // Allow system-driven dismissals (e.g., swipe-down on the keyboard),
                // and proactively clear our focus intent so we don't immediately re-focus.
                parent.isFirstResponder = false
                return true
            }

            func textFieldDidEndEditing(_ textField: UITextField) {
                // Reflect the keyboard being dismissed so we don't immediately re-focus.
                parent.isFirstResponder = false
            }
        }

        func makeCoordinator() -> Coordinator { Coordinator(self) }

        func makeUIView(context: Context) -> UITextField {
            let tf = UITextField()
            tf.delegate = context.coordinator
            tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
            tf.placeholder = placeholder
            tf.autocorrectionType = .yes
            tf.autocapitalizationType = .none
            tf.returnKeyType = .send
            tf.clearButtonMode = .never
            tf.borderStyle = .none
            tf.backgroundColor = .clear
            tf.enablesReturnKeyAutomatically = false
            return tf
        }

        func updateUIView(_ tf: UITextField, context: Context) {
            if tf.text != text { tf.text = text }
            // Only request first responder if asked; do NOT force a resign here.
            if isFirstResponder, !tf.isFirstResponder {
                tf.becomeFirstResponder()
            }
            // Intentionally do not call resignFirstResponder() here.
            // The system (e.g., swipe-down on keyboard) will handle dismissal.
        }
    }

    private struct InputBar: View {
        @Binding var draft: String
        @Binding var pickerItem: PhotosPickerItem?
        let onSend: () -> Void
        let onTapTextField: () -> Void
        let onFocusChanged: (Bool) -> Void

        @State private var isFirstResponder: Bool = false

        var body: some View {
            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                }
                NonResigningTextField(
                    text: $draft,
                    isFirstResponder: $isFirstResponder,
                    placeholder: "Message",
                    onReturn: {
                        onSend()
                        onTapTextField() // keep list pinned to bottom like iMessage
                        isFirstResponder = true
                    }
                )
                .onTapGesture {
                    isFirstResponder = true
                    onTapTextField()
                    onFocusChanged(true)
                }
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                Button(action: {
                    onSend()
                    onTapTextField()
                    isFirstResponder = true
                }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(draft.trimmed.isEmpty ? Color.gray.opacity(0.35) : Color.blue)
                        )
                }
                .disabled(draft.trimmed.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(height: 52)
            .background(.ultraThinMaterial)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                // When the user swipes the keyboard down, keep it dismissed by
                // updating our first-responder intent.
                isFirstResponder = false
            }
        }
    }

    // MARK: - Sheets (Date / Time)

    private struct DateSheet: View {
        @Environment(\.dismiss) private var dismiss
        @Binding var planDate: Date?
        let onConfirm: () -> Void
        let onCancel: () -> Void
        var body: some View {
            NavigationStack {
                VStack {
                    DatePicker("Pick a date",
                               selection: Binding(get: { planDate ?? Date() }, set: { planDate = $0 }),
                               displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .tint(.blue)
                        .padding(.horizontal, 12)
                    Spacer()
                }
                .navigationTitle("Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            onCancel()
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onConfirm()
                            dismiss()
                        }.bold()
                    }
                }
                .padding(.top, 8)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private struct TimeSheet: View {
        @Environment(\.dismiss) private var dismiss
        @Binding var planTime: Date?
        let defaultTime: Date
        let onConfirm: () -> Void
        let onCancel: () -> Void

        var body: some View {
            NavigationStack {
                VStack {
                    DatePicker("Pick a time",
                               selection: Binding(get: { planTime ?? defaultTime }, set: { planTime = $0 }),
                               displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .tint(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                    Spacer()
                }
                .navigationTitle("Time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            onCancel()
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onConfirm()
                            dismiss()
                        }.bold()
                    }
                }
            }
            .presentationDetents([.height(260), .medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Helpers / Formatters / Media / Seeding


    // Canonicalize activity names so minor spelling/casing/punctuation differences
    // don't fall back to the default 🎉 emoji.
    private func normalizeActivity(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Collapse repeated whitespace to a single space
        let collapsed = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // Strip common punctuation so "Pumpkin‑Patch", "pumpkin patch", etc. normalize the same.
        let stripped = collapsed.replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
        return stripped
    }

    private func activityEmoji(for selected: String?) -> String? {
        guard let name = selected, !name.isEmpty else { return "🎉" }
        let key = normalizeActivity(name)

        // Primary map (normalized keys)
        let map: [String: String] = [
            "boba": "🧋",
            "board game": "🎲",
            "boardgame": "🎲",          // accept no-space variant
            "brunch": "🥞",
            "coffee": "☕️",
            "dessert": "🍨",
            "golf": "⛳️",
            "hiking": "🥾",
            "karaoke": "🎤",
            "movie": "🎬",
            "museum": "🖼️",
            "pickleball": "🎾",
            "picnic": "🧺",
            "pool": "🎱",
            "pumpkin patch": "🎃",
            "pumpkinpatch": "🎃",
            "surfing": "🏄‍♂️",
            "theme park": "🎢",
            "themepark": "🎢"
        ]

        if let e = map[key] { return e }

        // Last-chance compact lookup (remove spaces)
        let compact = key.replacingOccurrences(of: " ", with: "")
        if let e = map[compact] { return e }

        return "🎉"
    }

    // Full pretty date: "Sept 25, Saturday" (abbreviated month, "Sept" for September)
    static func fullPrettyDate(_ date: Date) -> String {
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        let monthIndex = cal.component(.month, from: date) // 1...12
        // Abbreviations with "Sept" (not "Sep") as requested
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sept", "Oct", "Nov", "Dec"]
        let monthAbbrev = months[max(1, min(12, monthIndex)) - 1]
        let weekday = weekdayFullFormatter.string(from: date)
        return "\(monthAbbrev) \(day), \(weekday)"
    }

    private static let monthFullFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM"
        return df
    }()

    private static let weekdayFullFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        return df
    }()

    private static func ordinalSuffix(for day: Int) -> String {
        let ones = day % 10, tens = (day / 10) % 10
        if tens == 1 { return "th" }
        switch ones { case 1: return "st"; case 2: return "nd"; case 3: return "rd"; default: return "th" }
    }

    // Time formatter used by completion bar
    static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df
    }()

    static func timeString(_ date: Date) -> String { timeFormatter.string(from: date) }

    // Nearest next :00 or :30 for default time
    private func defaultNearestHalfHour(from date: Date) -> Date {
        let cal = Calendar.current
        let minute = cal.component(.minute, from: date)
        let add = minute < 30 ? (30 - minute) : (60 - minute)
        return cal.date(byAdding: .minute, value: add, to: date) ?? date
    }

    // Send text
    private func sendText() {
        let text = draft.trimmed
        guard !text.isEmpty else { return }
        draft = ""
        let msg = ChatMessage(senderID: appState.currentUser.id, text: text)
        messages.append(msg)
        pendingReply = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // Handle PhotosPicker item (image or video)
    private func handlePicked(_ item: PhotosPickerItem) async {
        mediaLoadError = nil
        isLoadingMedia = true
        defer { isLoadingMedia = false; pickerItem = nil }

        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            messages.append(ChatMessage(senderID: appState.currentUser.id, image: uiImage))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }

        do {
            if let url = try await item.loadTransferable(type: URL.self) {
                let tempURL = try persistVideo(at: url)
                messages.append(ChatMessage(senderID: appState.currentUser.id, videoURL: tempURL))
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                return
            }
        } catch { }

        mediaLoadError = "Couldn’t load that photo or video. Try a different file."
    }

    private func persistVideo(at sourceURL: URL) throws -> URL {
        let fm = FileManager.default
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let dest = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("chatvid-\(UUID().uuidString).\(ext)")
        if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
        try fm.copyItem(at: sourceURL, to: dest)
        return dest
    }

    // Top‑branch assignment & welcome messages
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

        if let leaderID = topBranchID,
           let leaderUser = (appState.matchedUsers + [appState.currentUser]).first(where: { $0.id == leaderID }) {
            let leaderName = leaderUser.id == appState.currentUser.id ? "You" : (leaderUser.name.isEmpty ? "Friend" : leaderUser.name)
            messages.append(ChatMessage(
                senderID: nil,
                text: " \(leaderName) is Top Branch 🌿. They're responsible for leading the conversation, gathering input, and entering the plan details as they're finalized.",
                isSystem: true
            ))
        }
        // Also post the activity-specific auto prompts right away so they appear together
        if let act = appState.selectedActivity, !act.isEmpty {
            postAutoPrompts(for: act)
        }
    }
}

// MARK: - Inline Venue Autocomplete (no magnifying glass, suggestions appear as you type)

private struct VenueInlineField: View {
    @Binding var planVenue: String?
    @Binding var planVenueAddress: String?
    @Binding var committedVenue: Bool
    var venueFieldFocused: FocusState<Bool>.Binding
    let gold: Bool
    let sheen: Bool

    @StateObject private var locator = InlineLocator()
    @StateObject private var ac = VenueAutocomplete()

    @State private var showSuggestions: Bool = false
    @State private var fieldText: String = ""
    @State private var suppressSuggestionsOnce: Bool = false

    var body: some View {
        // Use an overlay drop-down so expanding suggestions doesn't change layout height
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .leading) {
                // Background (gold + sheen, reused)
                GoldSheenBackground(isGold: gold, playSheen: sheen, cornerRadius: 14)

                // Foreground border reflecting filled/empty state
                let isEmpty = fieldText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isEmpty ? Color.clear : Color.blue.opacity(gold ? 0.06 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isEmpty
                                ? Color.gray.opacity(gold ? 0.15 : 0.25)
                                : (gold
                                   ? Color(red: 0.92, green: 0.78, blue: 0.40)
                                   : Color.blue.opacity(0.28)),
                                lineWidth: 1
                            )
                    )

                // Actual text field (no placeholder; we draw a left-aligned one below)
                TextField("", text: Binding(
                    get: { fieldText },
                    set: { newVal in
                        fieldText = newVal
                        planVenue = newVal.isEmpty ? nil : newVal
                        // Do NOT mark as committed while typing; only after user selects a suggestion
                        committedVenue = false
                        ac.update(query: newVal)
                        if suppressSuggestionsOnce {
                            // Skip reopening the dropdown for this programmatic change (from a tap selection)
                            showSuggestions = false
                            suppressSuggestionsOnce = false
                        } else {
                            showSuggestions = !newVal.isEmpty && !ac.items.isEmpty
                        }
                    }
                ))
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 37)
                .focused(venueFieldFocused)

                // Left‑aligned placeholder inside the pill
                if fieldText.isEmpty {
                    HStack {
                        Text("Venue")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(height: 37)
                    .padding(.horizontal, 14)
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 37)

            if committedVenue, let addr = planVenueAddress, !addr.isEmpty {
                Text(addr)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
            }
        }
        // Drop‑down overlay (does not affect layout)
        .overlay(alignment: .topLeading) {
            if showSuggestions && !ac.items.isEmpty {
                // Fixed-height scroll (≈4 rows visible), but can scroll for more
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(Array(ac.items.enumerated()), id: \.offset) { index, item in
                            Button(action: { selectSuggestion(item) }) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    if !item.subtitle.isEmpty {
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.systemBackground))
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())

                            if index < ac.items.count - 1 {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                }
                .scrollDismissesKeyboard(.never)
                .frame(height: (10 + 10 + 14) * 4) // ≈ 4 rows tall; adjust if needed
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 6)
                .offset(y: 42) // appear just under the pill
                .allowsHitTesting(true)
                .zIndex(20)
            }
        }
        .zIndex(showSuggestions ? 1000 : 0)
        .onAppear {
            fieldText = planVenue ?? ""
            locator.request()
        }
        .onReceive(locator.$region.compactMap { $0 }) { region in
            ac.region = region
        }
        .onChange(of: fieldText) { _, newVal in
            if suppressSuggestionsOnce {
                // Do not reopen suggestions due to this programmatic text change
                showSuggestions = false
                suppressSuggestionsOnce = false
                return
            }
            // Keep dropdown visibility in sync if results arrive later
            showSuggestions = !newVal.isEmpty && !ac.items.isEmpty
            if newVal.isEmpty {
                committedVenue = false
                planVenue = nil
                planVenueAddress = nil
            }
        }
        .preference(key: SuggestionsActiveKey.self, value: showSuggestions)
    }
    
    // Helper: best-effort immediate address from subtitle
    private func immediateAddress(from completion: MKLocalSearchCompletion) -> String? {
        let s = completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    private func selectSuggestion(_ item: MKLocalSearchCompletion) {
        // Immediate selection (one tap) — set BOTH name and a best-effort address right away
        let nameOnly = item.title
        suppressSuggestionsOnce = true
        fieldText = nameOnly
        planVenue = nameOnly
        planVenueAddress = immediateAddress(from: item) // show subtitle instantly if available
        committedVenue = true
        showSuggestions = false
        venueFieldFocused.wrappedValue = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Resolve precise postal address in the background and update if still the same selection
        Task { [selected = nameOnly] in
            let resolved = await resolveAddress(for: item, region: ac.completer.region)
            if planVenue == selected {
                // Prefer resolved if non-nil, else keep immediate subtitle
                if let r = resolved, !r.isEmpty { planVenueAddress = r }
            }
        }
    }

    private func resolveAddress(for completion: MKLocalSearchCompletion, region: MKCoordinateRegion?) async -> String? {
        var req = MKLocalSearch.Request(completion: completion)
        if let r = region { req.region = r }
        req.resultTypes = .pointOfInterest
        let search = MKLocalSearch(request: req)
        do {
            let resp = try await search.start()
            if let item = resp.mapItems.first {
                if let pa = item.placemark.postalAddress {
                    let street = pa.street
                    let city = pa.city
                    let state = pa.state
                    let postal = pa.postalCode
                    let parts = [street, [city, state].filter{ !$0.isEmpty }.joined(separator: ", "), postal].filter{ !$0.isEmpty }
                    return parts.joined(separator: ", ")
                }
                // Fallback to subtitle from completer if postalAddress missing
                return completion.subtitle
            }
        } catch { }
        return completion.subtitle.isEmpty ? nil : completion.subtitle
    }
}

// Lightweight location helper (inline variant)
private final class InlineLocator: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var region: MKCoordinateRegion?
    private let manager = CLLocationManager()

    func request() {
        manager.delegate = self
        if CLLocationManager.authorizationStatus() == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let span = MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
        region = MKCoordinateRegion(center: loc.coordinate, span: span)
        manager.stopUpdatingLocation()
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { }
}

// Autocomplete using MKLocalSearchCompleter (bias to region, POIs only)
private final class VenueAutocomplete: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var items: [MKLocalSearchCompletion] = []
    let completer = MKLocalSearchCompleter()
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest]
    }
    var region: MKCoordinateRegion? {
        didSet { if let r = region { completer.region = r } }
    }
    func update(query: String) {
        completer.queryFragment = query
    }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async { [weak self] in
            self?.items = completer.results
        }
    }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.items = []
        }
    }
}

// MARK: - Completion Field (no icon) — no internal checkmark

private struct CompletionFieldNoIcon: View {
    enum Style { case empty, filled }
    let title: String
    let placeholder: String
    let style: Style
    let tap: () -> Void
    let centered: Bool
    let gold: Bool
    let sheen: Bool

    var body: some View {
        Button(action: tap) {
            label
                .foregroundStyle(style == .empty ? .secondary : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    GoldSheenBackground(isGold: gold, playSheen: sheen, cornerRadius: 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            gold ? Color(red: 0.92, green: 0.78, blue: 0.40)
                                 : (style == .empty ? Color.gray.opacity(0.25) : Color.blue.opacity(0.28)),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var displayText: String { style == .empty ? placeholder : title }

    @ViewBuilder
    private var label: some View {
        if centered {
            Text(displayText)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            HStack(spacing: 6) {
                Text(displayText)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                Spacer()
            }
        }
    }
}

// Gold lock + sheen sweep background used by Venue / Date / Time pills
private struct GoldSheenBackground: View {
    var isGold: Bool
    var playSheen: Bool
    var cornerRadius: CGFloat = 14

    @State private var phase: CGFloat = -1.2

    var body: some View {
        ZStack {
            // Base fill
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isGold
                      ? Color(red: 0.98, green: 0.90, blue: 0.60) // soft gold
                      : Color(.systemBackground))

            if isGold {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color(red: 0.92, green: 0.78, blue: 0.40), lineWidth: 1)
            }

            // Sheen layer (animated sweep while playSheen is true)
            GeometryReader { geo in
                let w = geo.size.width
                let sheenWidth = max(40, w * 0.60) // wider band so it's more obvious

                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear,                    location: 0.00),
                        .init(color: .white.opacity(0.85),      location: 0.45),
                        .init(color: .white.opacity(0.50),      location: 0.55),
                        .init(color: .clear,                    location: 1.00)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: sheenWidth)
                .rotationEffect(.degrees(16))
                .offset(x: phase * (w + sheenWidth)) // travel fully across
                .opacity(playSheen ? 1.0 : 0.0)
                .onAppear { startIfNeeded() }
                .onChange(of: playSheen) { _, _ in startIfNeeded() }
            }
            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .allowsHitTesting(false)
        }
    }

    private func startIfNeeded() {
        if playSheen {
            // Restart from the left and sweep repeatedly until playSheen becomes false.
            phase = -1.2
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 1.4
            }
        } else {
            // Stop and hide the sheen quickly.
            withAnimation(.easeOut(duration: 0.2)) { phase = -1.2 }
        }
    }
}

// MARK: - Video bubble / utils

private struct VideoBubble: View {
    let url: URL
    @State private var player: AVPlayer? = nil
    var body: some View {
        VStack(spacing: 0) {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.gray.opacity(0.15), lineWidth: 1))
                    .onDisappear { player.pause() }
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(HStack(spacing: 8) {
                        ProgressView()
                        Text("Preparing video…").font(.footnote).foregroundStyle(.secondary)
                    })
                    .frame(height: 160)
            }
        }
        .onAppear { player = AVPlayer(url: url) }
    }
}

private extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }

private struct ScrollToBottomOnChange: ViewModifier {
    let count: Int
    let lastRowID: String?
    let proxy: ScrollViewProxy
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { _ in
                Color.clear.onChangeCompat(of: count) {
                    if let id = lastRowID {
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
    func onChangeCompat<T: Equatable>(of value: T, perform action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, *) { return self.onChange(of: value) { _, _ in action() } }
        else { return self.onChange(of: value) { _ in action() } }
    }
}

    // MARK: - Members Sheet

    private struct MembersSheet: View {
        let users: [User]
        @Environment(\.dismiss) private var dismiss
        var body: some View {
            NavigationStack {
                List {
                    ForEach(users, id: \.id) { u in
                        HStack(spacing: 12) {
                            // Simple initials circle
                            ZStack {
                                Circle().fill(Color.blue.opacity(0.12))
                                Text(initials(from: u.name))
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                            }
                            .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(u.name.isEmpty ? "Friend" : u.name)
                                    .font(.subheadline.weight(.semibold))
                                if let city = u.city, !city.isEmpty {
                                    Text(city)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Group members")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }.bold()
                    }
                }
            }
        }
        private func initials(from name: String) -> String {
            let parts = name.split(separator: " ")
            let letters = parts.prefix(2).compactMap { $0.first }
            return letters.isEmpty ? "•" : String(letters)
        }
    }

// MARK: - Name resolver (instance method)
extension ChatView {
    fileprivate func firstName(for id: UUID?) -> String {
        guard let id else { return "System" }
        if id == appState.currentUser.id {
            let n = appState.currentUser.name
            return n.split(separator: " ").first.map(String.init) ?? "You"
        }
        if let u = appState.matchedUsers.first(where: { $0.id == id }) {
            return u.name.split(separator: " ").first.map(String.init) ?? "Friend"
        }
        return "Friend"
    }
}

// MARK: - Venue Search Sheet

private struct VenueSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @StateObject private var locator = Locator()

    let onPick: (String, String?) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Inline search field
                HStack {
                    TextField("Search businesses", text: $query)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .onSubmit { performSearch() }
                        .submitLabel(.search)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if isSearching {
                    ProgressView().padding(.top, 12)
                }

                List {
                    ForEach(results, id: \.self) { item in
                        Button {
                            let name = item.name ?? "Venue"
                            let addr = fullPostalAddress(from: item.placemark) ?? formattedSubtitle(for: item)
                            onPick(name, addr)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "Unknown")
                                    .font(.subheadline.weight(.semibold))
                                if let addr = formattedSubtitle(for: item) {
                                    Text(addr).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Search venue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.bold()
                }
            }
            .onChange(of: query) { _, newValue in
                debounceSearch()
            }
            .onAppear { locator.request() }
        }
    }

    // MARK: - Search helpers

    private func performSearch() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { results = []; return }
        isSearching = true

        var req = MKLocalSearch.Request()
        req.naturalLanguageQuery = q
        req.resultTypes = .pointOfInterest
        if let region = locator.region {
            // Bias results to the user's current area
            req.region = region
        }

        let search = MKLocalSearch(request: req)
        search.start { resp, _ in
            isSearching = false
            results = resp?.mapItems ?? []
        }
    }

    private func fullPostalAddress(from placemark: CLPlacemark) -> String? {
        guard let pa = placemark.postalAddress else { return nil }
        let street = pa.street
        let city = pa.city
        let state = pa.state
        let postal = pa.postalCode
        let parts = [street, [city, state].filter { !$0.isEmpty }.joined(separator: ", "), postal]
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func formattedSubtitle(for item: MKMapItem) -> String? {
        guard let placemark = item.placemark.postalAddress else { return nil }
        let city = placemark.city
        let state = placemark.state
        return [city, state].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    // Simple debounce using DispatchWorkItem
    @State private var pendingWork: DispatchWorkItem?
    private func debounceSearch(delay: TimeInterval = 0.35) {
        pendingWork?.cancel()
        let work = DispatchWorkItem { performSearch() }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: - Lightweight location helper
    final class Locator: NSObject, ObservableObject, CLLocationManagerDelegate {
        @Published var region: MKCoordinateRegion?
        private let manager = CLLocationManager()

        func request() {
            manager.delegate = self
            // Use "When In Use" for lightweight biasing
            if CLLocationManager.authorizationStatus() == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else if CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.startUpdatingLocation()
            default:
                break
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let loc = locations.last else { return }
            let span = MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
            region = MKCoordinateRegion(center: loc.coordinate, span: span)
            // We just need a single fix to bias the search; stop for battery
            manager.stopUpdatingLocation()
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            // No-op: search will simply be un-biased
        }
    }
}

// MARK: - SuggestionsActiveKey Preference

private struct SuggestionsActiveKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

// MARK: - Keyboard Dismiss Helper

fileprivate func hideKeyboard() {
#if canImport(UIKit)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
}
