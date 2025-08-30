import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Shared types
enum TileKind { case top, regular, premium }

// MARK: - Palette aligned to app
private enum Palette {
    static let sky       = Color(red: 0.93, green: 0.98, blue: 1.00) // pale background blue
    static let mist      = Color(red: 0.86, green: 0.96, blue: 1.00)
    static let koala     = Color(red: 0.09, green: 0.27, blue: 0.55)
    static let leaf      = Color(red: 0.43, green: 0.79, blue: 0.62)
    static let stroke    = Color.black.opacity(0.10)
    static let text      = Color.black.opacity(0.85)
    static let bg        = Color(.systemBackground)
    // Stronger highlight (40% darker than original pale sky)
    static let highlight = Color(red: 0.55, green: 0.75, blue: 0.95)
}

// MARK: - Top Bar Button Style
private struct TopBarCircleButton: View {
    let systemName: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.koala)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .stroke(Palette.koala, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

struct ActivitySelectionView: View {
    // Per-activity swatches (restores the colorful buttons)
    private struct Swatch { let start: Color; let end: Color; let text: Color }
    private func swatch(for name: String) -> Swatch {
        switch name.lowercased() {
        case "hiking":         return .init(start: Color(red:0.70, green:0.85, blue:1.00), end: Color(red:0.55, green:0.75, blue:0.98), text: .black)
        case "pool":        return .init(start: Color(red:0.86, green:0.93, blue:1.00), end: Color(red:0.76, green:0.86, blue:0.98), text: .black)
        case "billiards":   return .init(start: Color(red:0.86, green:0.93, blue:1.00), end: Color(red:0.76, green:0.86, blue:0.98), text: .black)
        case "movie":          return .init(start: Color(red:0.74, green:0.72, blue:1.00), end: Color(red:0.66, green:0.64, blue:1.00), text: .black)
        case "pickleball":     return .init(start: Color(red:0.84, green:0.74, blue:1.00), end: Color(red:0.78, green:0.66, blue:1.00), text: .black)
        case "karaoke":        return .init(start: Color(red:0.76, green:0.78, blue:1.00), end: Color(red:0.69, green:0.71, blue:1.00), text: .black)
        case "coffee":         return .init(start: Color(red:1.00, green:0.78, blue:0.96), end: Color(red:0.98, green:0.68, blue:0.92), text: .black)
        case "golf":           return .init(start: Color(red:1.00, green:0.76, blue:0.92), end: Color(red:0.98, green:0.66, blue:0.88), text: .black)
        case "museum":         return .init(start: Color(red:1.00, green:0.78, blue:0.86), end: Color(red:1.00, green:0.70, blue:0.82), text: .black)
        case "yoga":           return .init(start: Color(red:0.78, green:0.88, blue:1.00), end: Color(red:0.70, green:0.82, blue:1.00), text: .black)
        case "boba":           return .init(start: Color(red:1.00, green:0.90, blue:0.74), end: Color(red:0.99, green:0.83, blue:0.63), text: .black)
        case "brunch":         return .init(start: Color(red:0.76, green:0.74, blue:1.00), end: Color(red:0.68, green:0.66, blue:1.00), text: .black)
        case "surfing":        return .init(start: Color(red:0.67, green:0.90, blue:0.98), end: Color(red:0.56, green:0.86, blue:0.96), text: .black)
        case "pumpkin patch":  return .init(start: Color(red:1.00, green:0.85, blue:0.69), end: Color(red:1.00, green:0.78, blue:0.58), text: .black)
        case "theme park":     return .init(start: Color(red:1.00, green:0.78, blue:0.72), end: Color(red:1.00, green:0.70, blue:0.60), text: .black)
        case "road trip":      return .init(start: Color(red:0.80, green:0.90, blue:1.00), end: Color(red:0.68, green:0.82, blue:1.00), text: .black)
        case "speakeasy":      return .init(start: Color(red:0.98, green:0.82, blue:0.98), end: Color(red:0.94, green:0.74, blue:0.94), text: .black)
        case "escape room":    return .init(start: Color(red:0.86, green:0.87, blue:1.00), end: Color(red:0.78, green:0.80, blue:1.00), text: .black)
        // Additional swatches for all activities:
        case "restaurant":      return .init(start: Color(red:0.90, green:0.95, blue:1.00), end: Color(red:0.80, green:0.88, blue:1.00), text: .black)
        case "minigolf":        return .init(start: Color(red:0.86, green:1.00, blue:0.86), end: Color(red:0.78, green:0.96, blue:0.78), text: .black)
        case "beach":           return .init(start: Color(red:1.00, green:0.92, blue:0.75), end: Color(red:0.86, green:0.96, blue:1.00), text: .black)
        case "dessert":         return .init(start: Color(red:1.00, green:0.82, blue:0.90), end: Color(red:1.00, green:0.74, blue:0.86), text: .black)
        case "farmer's market": return .init(start: Color(red:0.86, green:1.00, blue:0.86), end: Color(red:0.96, green:0.88, blue:0.72), text: .black)
        case "jam session":     return .init(start: Color(red:0.92, green:0.82, blue:1.00), end: Color(red:0.86, green:0.72, blue:1.00), text: .black)
        case "wine tasting":    return .init(start: Color(red:1.00, green:0.80, blue:0.88), end: Color(red:0.96, green:0.68, blue:0.78), text: .black)
        case "concert":         return .init(start: Color(red:0.78, green:0.86, blue:1.00), end: Color(red:0.70, green:0.80, blue:1.00), text: .black)
        case "d&d":             return .init(start: Color(red:0.82, green:0.78, blue:1.00), end: Color(red:0.74, green:0.70, blue:1.00), text: .black)
        case "sports event":    return .init(start: Color(red:0.78, green:1.00, blue:0.90), end: Color(red:0.68, green:0.92, blue:0.84), text: .black)
        case "jazz club":       return .init(start: Color(red:0.76, green:0.86, blue:1.00), end: Color(red:0.66, green:0.78, blue:1.00), text: .black)
        case "mtg":             return .init(start: Color(red:1.00, green:0.90, blue:0.75), end: Color(red:0.84, green:0.76, blue:1.00), text: .black)
        case "picnic":          return .init(start: Color(red:0.88, green:1.00, blue:0.88), end: Color(red:0.78, green:0.92, blue:0.78), text: .black)
        case "trivia night":    return .init(start: Color(red:1.00, green:0.95, blue:0.75), end: Color(red:0.76, green:0.86, blue:1.00), text: .black)
        case "board game":      return .init(start: Color(red:0.80, green:1.00, blue:0.98), end: Color(red:0.70, green:0.92, blue:0.92), text: .black)
        default:                return .init(start: Palette.sky, end: Palette.mist, text: Palette.text)
        }
    }
    private func gradient(for name: String) -> LinearGradient {
        let s = swatch(for: name)
        return LinearGradient(colors: [s.start, s.end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    @EnvironmentObject var appState: AppState
    
    // MARK: Top-level
    private let topLevelActivities: [ActivityItem] = [
        .init(name: "theme park",     emoji: "🎢"),
        .init(name: "brunch",         emoji: "🥞"),
        .init(name: "movie",          emoji: "🎬"),
        .init(name: "picnic",         emoji: "🧺"),
        .init(name: "trivia night",   emoji: "🧠"),
        .init(name: "board game",     emoji: "🎲"),
        .init(name: "beach",          emoji: "🏖️"),
        .init(name: "dessert",        emoji: "🍰"),
        .init(name: "farmer's market",emoji: "🥕")
    ]
    
    // MARK: Regular
    private let regularActivities: [ActivityItem] = [
        .init(name: "restaurant",        emoji: "🍽️", badge: "CURATED", badgeAboveTitle: true, smallBadge: false),
        .init(name: "hiking",            emoji: "🥾"),
        .init(name: "dessert",           emoji: "🍰"),
        .init(name: "pool",              emoji: "🎱"),
        .init(name: "karaoke",           emoji: "🎤"),
        .init(name: "boba",              emoji: "🧋"),
        .init(name: "coffee",            emoji: "☕️"),
        .init(name: "board game",        emoji: "🎲"),
        .init(name: "pickleball",        emoji: "🎾")
    ]
    
    // MARK: Premium
    private let premiumActivities: [ActivityItem] = [
        .init(name: "pumpkin patch",  emoji: "🎃", badge: "SEASONAL", badgeAboveTitle: true, smallBadge: true),
        .init(name: "surfing",        emoji: "🏄‍♂️"),
        .init(name: "speakeasy",      emoji: "🍸"),
        .init(name: "jam session",    emoji: "🎸"),
        .init(name: "golf",           emoji: "⛳️"),
        .init(name: "escape room",    emoji: "🗝️"),
        .init(name: "wine tasting",   emoji: "🍷"),
        .init(name: "concert",        emoji: "🎵"),
        .init(name: "D&D",            emoji: "🐉"),
        .init(name: "sports event",   emoji: "🏟️"),
        .init(name: "jazz club",      emoji: "🎷"),
        .init(name: "MTG",            emoji: "🃏")
    ]
    
    // Selection
    @State private var tempSelectedActivity: String? = nil
    @State private var showTips: Bool = false
    @State private var showTopLevelTips: Bool = false
    @State private var tipSheetHeight: CGFloat = 0
    // Only reflect the in-screen temporary choice so deselecting clears all checks.
    private var effectiveSelection: String? { tempSelectedActivity }
    private var canContinue: Bool { effectiveSelection != nil }
    
    var body: some View {
        VStack(spacing: 0) {
            // Centered title with leading home and trailing continue actions
            ZStack {
                // Center title + tiny italic "i" info button
                HStack(spacing: 4) {
                    Text("Pick An Activity")
                        .font(.custom("Avenir-Heavy", size: 22))
                        .foregroundStyle(Palette.koala)
                    // Superscript-style italic "i"
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showTips = true
                    } label: {
                        Text("i")
                            .italic()
                            .font(.system(size: 13, weight: .bold, design: .default))
                            .baselineOffset(6) // raise like an exponent
                            .foregroundStyle(Palette.koala.opacity(0.9))
                            .padding(.leading, 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Activity tips")
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // Leading + Trailing controls
                HStack {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        appState.goToHub()
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

                    Button(action: {
                        guard let choice = effectiveSelection else { return }
                        appState.selectedActivity = choice
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        appState.goToGroupSize()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Continue")
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.35)
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Scrollable sections: each is a horizontally paged 3-row grid
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) { // tighter space between categories
                    pagedThreeRowSection(items: regularActivities, kind: .regular)

                    SectionLabelDividerWithInfo(title: "Top-level", onInfo: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); showTopLevelTips = true })
                        .anchorPreference(key: TopLevelTipAnchorKey.self, value: .bounds) { $0 }
                    pagedThreeRowSection(items: topLevelActivities, kind: .top)

                    SectionLabelDivider(title: "Premium")
                    pagedThreeRowSection(items: premiumActivities, kind: .premium)
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .onAppear { tempSelectedActivity = appState.selectedActivity }
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .top) {
            if showTips {
                ZStack(alignment: .top) {
                    // Full-screen tappable backdrop (dismisses on tap)
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { showTips = false }
                    // Popover itself
                    TipsPopover(
                        message: "Choose an activity you'd like to do this week. You'll have seven days after matching to plan and attend this activity.",
                        onClose: { showTips = false }
                    )
                        .onTapGesture { showTips = false }
                        .padding(.top, 12)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: showTips)
                .zIndex(1000)
            }
        }
        .onPreferenceChange(TipHeightKey.self) { h in
            tipSheetHeight = h
        }
        .overlayPreferenceValue(TopLevelTipAnchorKey.self) { anchor in
            GeometryReader { proxy in
                ZStack {
                    if showTopLevelTips, let a = anchor {
                        // Full-screen tappable backdrop to dismiss
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture { showTopLevelTips = false }
                            .zIndex(999)

                        // Compute the target rect from the anchor
                        let rect = proxy[a]

                        // Popover positioned above the Top-level label using measured height
                        TipsPopover(
                            message: "Unlocked when you receive an upvote as top branch, maintain four stars, or attend two activities in a four week span.",
                            onClose: { showTopLevelTips = false }
                        )
                        .onTapGesture { showTopLevelTips = false }
                        .position(
                            x: rect.midX,
                            y: max(24, rect.minY - (tipSheetHeight / 2) - 40)
                        )
                        .zIndex(1000)
                    }
                }
            }
        }
    }
    
    // MARK: - Section Divider Label
    private struct SectionLabelDivider: View {
        let title: String
        var body: some View {
            HStack(spacing: 8) {
                Rectangle().fill(Palette.stroke).frame(height: 1)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Palette.koala.opacity(0.9))
                Rectangle().fill(Palette.stroke).frame(height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 1.8)
        }
    }

    private struct SectionLabelDividerWithInfo: View {
        let title: String
        let onInfo: () -> Void
        var body: some View {
            HStack(spacing: 8) {
                Rectangle().fill(Palette.stroke).frame(height: 1)
                HStack(spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(Palette.koala.opacity(0.9))
                    Button(action: onInfo) {
                        Text("i")
                            .italic()
                            .font(.system(size: 11, weight: .bold))
                            .baselineOffset(4)
                            .foregroundStyle(Palette.koala.opacity(0.9))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Top-level tips")
                }
                Rectangle().fill(Palette.stroke).frame(height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 1.8)
        }
    }

    // MARK: - Scrolling helpers
    private func kindKey(_ kind: TileKind) -> String {
        switch kind { case .regular: return "reg"; case .top: return "top"; case .premium: return "pre" }
    }
    private func sectionScrollID(kind: TileKind, column: Int) -> String { "\(kindKey(kind))-col-\(column)" }

    private func scrollToSelection(_ proxy: ScrollViewProxy, items: [ActivityItem], rowsPerColumn: Int, kind: TileKind) {
        // Prefer the in-screen temp selection; fall back to persisted app selection on first load
        let selectedName = effectiveSelection ?? appState.selectedActivity
        guard let name = selectedName, let idx = items.firstIndex(where: { $0.name == name }) else { return }

        // Column index for the selected item (column-major, 3 rows per column)
        let col = max(0, idx / rowsPerColumn)

        // If the selected item is in the first two columns (0 or 1), do not auto-scroll.
        // This preserves the default initial position while still showing the checkmark.
        guard col >= 2 else { return }

        // Otherwise, snap to the start of the two-column page that contains this column
        let pageStart = (col / 2) * 2
        let targetID = sectionScrollID(kind: kind, column: pageStart)

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(targetID, anchor: .leading)
            }
        }
    }

    // MARK: - Draggable 3-row section (2 columns shown at a time, snap)
    @ViewBuilder
    private func pagedThreeRowSection(items: [ActivityItem], kind: TileKind) -> some View {
        GeometryReader { geo in
            // Layout constants
            let outerPadding: CGFloat = 16
            let interColumnSpacing: CGFloat = 12   // uniform spacing between ALL columns
            let rowSpacing: CGFloat = 6            // spacing between rows inside a column
            let rowHeight: CGFloat = 64
            let rowsPerColumn: Int = 3

            let viewportWidth: CGFloat = geo.size.width
            let contentWidth: CGFloat = viewportWidth - (outerPadding * 2)
            // Two columns visible at once → 2*cardWidth + interColumnSpacing == contentWidth
            let cardWidth: CGFloat = (contentWidth - interColumnSpacing) / 2

            // Height is based on max rows to keep bands consistent
            let sectionHeight: CGFloat = (CGFloat(rowsPerColumn) * rowHeight)
                + (CGFloat(rowsPerColumn - 1) * rowSpacing)
                + 10

            // Build columns (column-major): each column has up to 3 items, filled top→bottom
            let columns: [[ActivityItem]] = columnize(items, rowsPerColumn: rowsPerColumn)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: interColumnSpacing) {
                        ForEach(columns.indices, id: \.self) { colIdx in
                            let colItems = columns[colIdx]
                            VStack(spacing: rowSpacing) {
                                ForEach(colItems, id: \.id) { item in
                                    activityTile(for: item, kind: kind)
                                        .frame(width: cardWidth, height: rowHeight)
                                }
                                // pad short columns to full height (keeps top alignment and snap math consistent)
                                if colItems.count < rowsPerColumn {
                                    ForEach(colItems.count..<rowsPerColumn, id: \.self) { _ in
                                        Color.clear
                                            .frame(width: cardWidth, height: rowHeight)
                                    }
                                }
                            }
                            .frame(width: cardWidth, height: sectionHeight, alignment: .top)
                            .contentShape(Rectangle())
                            .id(sectionScrollID(kind: kind, column: colIdx))
                        }
                    }
                    .frame(height: sectionHeight)
                    .padding(.horizontal, outerPadding)
                    .contentShape(Rectangle())
                }
                .frame(height: sectionHeight)
                .onAppear { scrollToSelection(proxy, items: items, rowsPerColumn: rowsPerColumn, kind: kind) }
                // Removed .onChange(of: effectiveSelection) to prevent automatic scroll on selection change
            }
        }
        .frame(height: (64 * 3) + (6 * 2) + 10)
    }

    // MARK: - Utilities
    private func chunk<T>(_ array: [T], by size: Int) -> [[T]] {
        guard size > 0 else { return [array] }
        var result: [[T]] = []
        var index = 0
        while index < array.count {
            let end = min(index + size, array.count)
            result.append(Array(array[index..<end]))
            index = end
        }
        return result
    }

    // Column-major pagination: fills each column with up to `rowsPerColumn` items top-to-bottom,
    // then moves to the next column. Groups columns into pages of `columnsPerPage`.
    private func columnPaged<T>(_ items: [T], rowsPerColumn: Int, columnsPerPage: Int) -> [[[T]]] {
        guard rowsPerColumn > 0 && columnsPerPage > 0 else { return [[]] }

        // Split into columns first (each column has up to rowsPerColumn items)
        var columns: [[T]] = []
        var idx = 0
        while idx < items.count {
            let end = min(idx + rowsPerColumn, items.count)
            columns.append(Array(items[idx..<end]))
            idx = end
        }

        // Group columns into pages
        var pages: [[[T]]] = []
        var colIndex = 0
        while colIndex < columns.count {
            let end = min(colIndex + columnsPerPage, columns.count)
            pages.append(Array(columns[colIndex..<end]))
            colIndex = end
        }
        return pages
    }

    // Split into columns of up to `rowsPerColumn` items (column-major order)
    private func columnize<T>(_ items: [T], rowsPerColumn: Int) -> [[T]] {
        guard rowsPerColumn > 0 else { return [] }
        var cols: [[T]] = []
        var idx = 0
        while idx < items.count {
            let end = min(idx + rowsPerColumn, items.count)
            cols.append(Array(items[idx..<end]))
            idx = end
        }
        return cols
    }
    
    // Persist temp activity choice to Firestore on selection.
    private func updateSelectedActivityInFirestore(_ name: String?) {
        // Only write if we have an authenticated user
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        var data: [String: Any] = ["updatedAt": FieldValue.serverTimestamp()]
        if let n = name, !n.isEmpty {
            data["selectedActivity"] = n
        } else {
            // If user deselects, remove the temp field
            data["selectedActivity"] = FieldValue.delete()
        }
        db.collection("users").document(uid).setData(data, merge: true)
    }

    // MARK: - Tile Builder
    private func activityTile(for item: ActivityItem, kind: TileKind) -> some View {
        let isSelected = (effectiveSelection == item.name)
        let grad = gradient(for: item.name)
        let sw = swatch(for: item.name)
        return ActivityTile(
            title: item.name,
            emoji: item.emoji,
            badge: item.badge,
            badgeAboveTitle: item.badgeAboveTitle,
            smallBadge: item.smallBadge,
            kind: kind,
            isSelected: isSelected,
            action: {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                let newValue: String? = (isSelected ? nil : item.name)
                withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                    tempSelectedActivity = newValue
                }
                // Write the temp choice to Firestore immediately
                updateSelectedActivityInFirestore(newValue)
            },
            fillStyle: grad,
            baseTextColor: sw.text
        )
    }
}

// MARK: - Tile

private struct ActivityTile: View {
    let title: String
    let emoji: String
    let badge: String?
    let badgeAboveTitle: Bool
    let smallBadge: Bool
    let kind: TileKind
    let isSelected: Bool
    let action: () -> Void
    let fillStyle: LinearGradient
    let baseTextColor: Color

    private var corner: CGFloat { 16 }
    private var height: CGFloat { 56 }
    // New computed property to indicate locked state
    private var isLocked: Bool { false } // TEMP: unlock for interaction
    // Style rules
    private var stroke: Color {
        if isSelected { return Palette.koala }
        if (kind == .premium || kind == .top) { return Palette.leaf }
        return Palette.stroke
    }
    private var strokeWidth: CGFloat { isSelected ? 2 : 1 }
    private var fill: AnyShapeStyle {
        isSelected ? AnyShapeStyle(fillStyle.opacity(0.95)) : AnyShapeStyle(fillStyle)
    }
    private var textColor: Color { baseTextColor }
    private var isDimmed: Bool { false }

    @ViewBuilder
    private var cornerBadge: some View {
        switch kind {
        case .top:
            SmallBadge(systemName: "lock.fill", fg: Palette.koala)
        case .premium:
            SmallBadge(systemName: "star.fill", fg: Color.yellow)
        default:
            EmptyView()
        }
    }

    // Badge pill helper, to be overlaid top-center
    @ViewBuilder
    private var badgePill: some View {
        if let badge {
            Text(badge)
                .font(.system(size: smallBadge ? 9 : 10, weight: .bold)) // smaller than before
                .foregroundStyle(Palette.koala)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.sky)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1)
                )
        }
    }

    var body: some View {
        Button(action: { action() }) {
            contentLayer
                .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        }
        .buttonStyle(TilePressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var contentLayer: some View {
        VStack(spacing: 0) {
            // Main centered content
            HStack(spacing: 10) {
                Text(emoji).font(.system(size: 18))
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 12)
            .padding(.top, (badgeAboveTitle && badge != nil) ? 10 : 0)
        }
        .foregroundStyle(textColor)
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous).fill(fill)
        )
        // Top-center badge overlay (does not shift content vertically)
        .overlay(alignment: .top) {
            if badgeAboveTitle, badge != nil {
                HStack { Spacer(); badgePill; Spacer() }
                    .padding(.top, 6) // sit clear of the top border without changing tile height
                    .padding(.horizontal, 6)
                    .allowsHitTesting(false)
            }
        }
        // Top-right selection/check or tier badge
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(8)
            } else {
                cornerBadge
                    .padding(8)
            }
        }
        // Draw stroke LAST so it stays visible over any overlays
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(stroke, lineWidth: strokeWidth)
                .animation(.easeInOut(duration: 0.18), value: strokeWidth)
        )
    }
}

private struct SmallBadge: View {
    let systemName: String
    let fg: Color
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(fg)
    }
}

// MARK: - Tile Press Style
private struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.18), value: configuration.isPressed)
    }
}

// MARK: - Micro-interaction helpers

private struct SelectionSpring: ViewModifier {
    let isSelected: Bool
    @State private var scale: CGFloat = 1.0
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: isSelected) { sel in
                if sel {
                    withAnimation(.spring(response: 0.20, dampingFraction: 0.90)) { scale = 1.02 }
                    withAnimation(.easeOut(duration: 0.12).delay(0.08)) { scale = 1.0 }
                } else {
                    withAnimation(.easeInOut(duration: 0.12)) { scale = 1.0 }
                }
            }
    }
}
private extension View { func selectionSpring(_ b: Bool) -> some View { modifier(SelectionSpring(isSelected: b)) } }

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

// MARK: - Model
private struct ActivityItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let emoji: String
    var badge: String? = nil
    var badgeAboveTitle: Bool = false
    var smallBadge: Bool = false
}

// MARK: - Availability helper
private extension View {
    @ViewBuilder
    func ifAvailableiOS17<Content: View>(_ transform: (Self) -> Content) -> some View {
        if #available(iOS 17.0, *) { transform(self) } else { self }
    }
}


private struct TipsPopover: View {
    let message: String
    let onClose: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 14, x: 0, y: 10)
        .frame(maxWidth: 320)
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: TipHeightKey.self, value: geo.size.height)
            }
        )
        .contentShape(Rectangle())
        .onTapGesture { onClose() }
    }
}

private struct TipHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TopLevelTipAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        // Keep the first non-nil anchor; update if value is nil
        value = value ?? nextValue()
    }
}
