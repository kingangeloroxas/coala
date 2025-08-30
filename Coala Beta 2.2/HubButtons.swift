import SwiftUI

private let hubDockButtonSize: CGFloat = 67 // 84 * 0.8 = 67.2 → 67

// MARK: - Small haptics helper
private func tapHaptic() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}

// MARK: - Concrete buttons that wrap your reusable CircularIconButton

struct ProfileButton: View {
    var size: CGFloat = hubDockButtonSize
    var onTap: () -> Void = { tapHaptic(); print("Profile tapped (placeholder)") }

    var body: some View {
        CircularIconButton(
            imageName: "profile_button",   // make sure this PNG exists in Assets
            size: size,
            ringColor: Color.blue.opacity(0.35),
            action: onTap
        )
    }
}

struct MenuButton: View {
    var size: CGFloat = hubDockButtonSize
    var onTap: () -> Void = { tapHaptic(); print("Menu tapped (placeholder)") }

    var body: some View {
        CircularIconButton(
            imageName: "hubmenu_button",   // make sure this PNG exists in Assets
            size: size,
            ringColor: Color.blue.opacity(0.35),
            action: onTap
        )
    }
}

struct MiniGamesButton: View {
    var size: CGFloat = hubDockButtonSize
    var onTap: () -> Void = { tapHaptic(); print("Mini‑Games tapped (placeholder)") }

    var body: some View {
        CircularIconButton(
            imageName: "minigames_button", // make sure this PNG exists in Assets
            size: size,
            ringColor: Color.blue.opacity(0.35),
            action: onTap
        )
    }
}

// MARK: - Dock (rounded bar you place at the bottom of HubView)

struct HubDock: View {
    var buttonSize: CGFloat = hubDockButtonSize

    // You can override these from HubView later to perform real navigation.
    var onProfileTap: () -> Void = { tapHaptic(); print("Profile tapped (placeholder)") }
    var onMenuTap: () -> Void = { tapHaptic(); print("Menu tapped (placeholder)") }
    var onMiniGamesTap: () -> Void = { tapHaptic(); print("Mini‑Games tapped (placeholder)") }

    @State private var showCoalaplus = false

    var body: some View {
        HStack(spacing: 36) {
            ProfileButton(size: buttonSize, onTap: { tapHaptic(); showCoalaplus = true })
            MenuButton(size: buttonSize, onTap: onMenuTap)
            MiniGamesButton(size: buttonSize, onTap: onMiniGamesTap)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 22)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 14, y: 8)
        .frame(minWidth: 360, maxWidth: .infinity)
        .fullScreenCover(isPresented: $showCoalaplus) {
            CoalaplusTempScreen { showCoalaplus = false }
        }
    }
}

struct CoalaplusTempScreen: View {
    var onClose: () -> Void
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Full-bleed graphic
            Color.white.ignoresSafeArea()
            Image("coalaplus")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            // Close button (X) in the top‑right
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close")
        }
    }
}

// MARK: - Preview

#if DEBUG
struct HubDock_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            HubDock()
                .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
#endif
