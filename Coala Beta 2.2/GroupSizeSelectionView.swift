import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Palette aligned to your app motif
private enum PaletteGS {
    static let sky     = Color(red: 0.93, green: 0.98, blue: 1.00) // light blue surface
    static let mist    = Color(red: 0.86, green: 0.96, blue: 1.00)
    static let koala   = Color(red: 0.09, green: 0.27, blue: 0.55) // brand primary
    static let stroke  = Color.black.opacity(0.10)
    static let text    = Color.black.opacity(0.85)
}

struct GroupSizeSelectionView: View {
    @EnvironmentObject var appState: AppState

    private let sizes = [4, 6, 8]

    // Selection
    @State private var tempSize: Int? = nil
    private var effectiveSize: Int? { tempSize ?? appState.selectedGroupSize }
    private var canContinue: Bool { effectiveSize != nil }

    // Press-and-hold tracking
    @GestureState private var pressedID: Int? = nil

    // Layout tuning
    private let topOffset: CGFloat = 44           // ⬇️ shift the whole screen down
    private let buttonHeight: CGFloat = 60        // shorter buttons
    private let itemSpacing: CGFloat = 20         // generous vertical spacing

    // Activity chip visuals
    private let activityMeta: [String: (emoji: String, color: Color)] = [
        "Hiking": ("🥾", Color(hue: 220/360, saturation: 0.32, brightness: 0.98)),
        "Bowling": ("🎳", Color(hue: 235/360, saturation: 0.32, brightness: 0.98)),
        "Movie": ("🎬", Color(hue: 250/360, saturation: 0.32, brightness: 0.98)),
        "Pickleball": ("🎾", Color(hue: 270/360, saturation: 0.32, brightness: 0.98)),
        "Karaoke": ("🎤", Color(hue: 285/360, saturation: 0.32, brightness: 0.98)),
        "Coffee": ("☕️", Color(hue: 300/360, saturation: 0.32, brightness: 0.98)),
        "Golf": ("⛳️", Color(hue: 315/360, saturation: 0.32, brightness: 0.98)),
        "Museum": ("🖼️", Color(hue: 330/360, saturation: 0.32, brightness: 0.98)),
        "Yoga": ("🧘", Color(hue: 210/360, saturation: 0.32, brightness: 0.98)),
        "Boba": ("🧋", Color(hue:  40/360, saturation: 0.32, brightness: 0.98)),
        "Brunch": ("🥞", Color(hue: 240/360, saturation: 0.35, brightness: 0.98)),
        "Surfing": ("🏄‍♂️", Color(hue: 190/360, saturation: 0.35, brightness: 0.98)),
        "Pumpkin Patch": ("🎃", Color(hue:  30/360, saturation: 0.35, brightness: 0.98)),
        "Theme Park": ("🎢", Color(hue:  15/360, saturation: 0.35, brightness: 0.98))
    ]

    // Persist the live selection to Firestore under top-level `selectedGroupSize`
    private func persistSelectedGroupSize(_ size: Int?) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[GroupSizeSelection] No authenticated user; skip save")
            return
        }
        let doc = Firestore.firestore().collection("users").document(uid)

        if let size = size {
            doc.setData(["selectedGroupSize": size, "updatedAt": FieldValue.serverTimestamp()], merge: true) { error in
                if let error = error {
                    print("[GroupSizeSelection] Failed to save selectedGroupSize: \(error.localizedDescription)")
                } else {
                    print("[GroupSizeSelection] selectedGroupSize saved (size=\(size))")
                }
            }
        } else {
            // Clear if needed
            doc.setData(["selectedGroupSize": FieldValue.delete(), "updatedAt": FieldValue.serverTimestamp()], merge: true) { error in
                if let error = error { print("[GroupSizeSelection] Failed to clear selectedGroupSize: \(error.localizedDescription)") }
            }
        }
    }

    // On Continue, confirm the choice into `tempSelection.groupSize`
    private func confirmGroupSizeToTempSelection(_ size: Int) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        var payload: [String: Any] = [
            "groupSize": size,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let act = appState.selectedActivity { payload["activity"] = act }

        Firestore.firestore()
            .collection("users").document(uid)
            .setData(["tempSelection": payload], merge: true) { error in
                if let error = error {
                    print("[GroupSizeSelection] Failed to confirm tempSelection: \(error.localizedDescription)")
                } else {
                    print("[GroupSizeSelection] tempSelection confirmed (size=\(size))")
                }
            }
    }

    private func toggleSize(_ size: Int) {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.9)) {
            tempSize = (tempSize == size) ? nil : size
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: topOffset) // ⬇️ lower everything

            // ===== Selected Activity Header + Change link =====
            if let act = appState.selectedActivity,
               let meta = activityMeta[act] {
                HStack {
                    Text("Selected Activity")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button("Change") { appState.goBack() }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                MiniActivityBubble(
                    title: act,
                    emoji: meta.emoji,
                    color: meta.color,
                    onTap: { appState.goBack() }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            // ===== Prompt =====
            Text("How big would you like your group to be?")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(PaletteGS.koala)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 28)

            // ===== Size buttons (compact height, roomy spacing) =====
            VStack(spacing: itemSpacing) {
                ForEach(sizes, id: \.self) { size in
                    GroupSizeButton(
                        size: size,
                        isSelected: tempSize == size,
                        isPressed: pressedID == size,
                        height: buttonHeight
                    ) {
                        toggleSize(size)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($pressedID) { _, state, _ in state = size }
                            .onEnded { _ in
                                toggleSize(size)
                            }
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 28)

            // ===== Continue =====
            Button {
                guard let size = effectiveSize else { return }

                // Confirm final choice into tempSelection on Continue
                confirmGroupSizeToTempSelection(size)

                // Update local state and proceed
                appState.selectedGroupSize = size
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                appState.goToMatching()
            } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.4)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .onAppear {
            tempSize = appState.selectedGroupSize
            if let s = tempSize {
                persistSelectedGroupSize(s)
            }
        }
        .onChange(of: tempSize) { newValue in
            // Save immediately when a size is chosen
            if let s = newValue {
                appState.selectedGroupSize = s
                persistSelectedGroupSize(s)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Group Size Button (text-only, compact height)
private struct GroupSizeButton: View {
    let size: Int
    let isSelected: Bool
    let isPressed: Bool
    let height: CGFloat
    let action: () -> Void

    private let corner: CGFloat = 16
    private var pressScale: CGFloat { 0.94 }

    private var isLocked: Bool { size == 8 }

    private var fill: some ShapeStyle {
        if isLocked {
            return Color.gray
        } else {
            return isSelected ? PaletteGS.koala : PaletteGS.sky
        }
    }
    private var textColor: Color {
        if isLocked {
            return .gray
        } else {
            return isSelected ? .white : PaletteGS.text
        }
    }
    private var borderColor: Color {
        if isLocked {
            return Color.gray.opacity(0.4)
        } else {
            return isSelected ? Color.white.opacity(0.9) : PaletteGS.stroke
        }
    }

    var body: some View {
        Button(action: {
            if !isLocked {
                action()
            }
        }) {
            ZStack(alignment: .topTrailing) {
                if isSelected {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(PaletteGS.koala.opacity(0.22))
                        .blur(radius: 14)
                        .offset(y: 2)
                }

                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(fill)

                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)

                // Big text that scales with button height
                Text("\(size) people")
                    .font(.system(size: height * 0.48, weight: .bold, design: .rounded))
                    .foregroundStyle(textColor)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                        .padding(8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? pressScale : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isPressed)
        .animation(.spring(response: 0.26, dampingFraction: 0.9), value: isSelected)
        .accessibilityLabel("\(size) people")
        .accessibilityAddTraits(.isButton)
        .disabled(isLocked)
    }
}

// MARK: - Selected Activity Bubble (unchanged)
private struct MiniActivityBubble: View {
    let title: String
    let emoji: String
    let color: Color
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 10) {
                Spacer()
                Text(emoji).font(.system(size: 22))
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
