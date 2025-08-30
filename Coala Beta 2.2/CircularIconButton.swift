//
//  CircularIconButton.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/23/25.
//


import SwiftUI

/// Reusable circular image button with tap haptics + shadow pulse animation.
public struct CircularIconButton: View {
    public var imageName: String
    public var size: CGFloat = 84
    public var ringColor: Color = Color.blue.opacity(0.35)
    public var action: () -> Void

    @State private var isPressed: Bool = false
    @State private var pulseProgress: CGFloat = 1 // 0 → 1 animates a ring outward & fading

    public init(
        imageName: String,
        size: CGFloat = 84,
        ringColor: Color = Color.blue.opacity(0.35),
        action: @escaping () -> Void
    ) {
        self.imageName = imageName
        self.size = size
        self.ringColor = ringColor
        self.action = action
    }

    public var body: some View {
        Button {
            // Haptic
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // Click (shrink) + pulse ring
            withAnimation(.spring(response: 0.18, dampingFraction: 0.75)) {
                isPressed = true
                pulseProgress = 0
            }
            withAnimation(.easeOut(duration: 0.45)) {
                pulseProgress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.85)) {
                    isPressed = false
                }
            }

            action()
        } label: {
            ZStack {
                // Expanding/fading ring (shadow pulse)
                Circle()
                    .stroke(ringColor, lineWidth: 10)
                    .frame(width: size * 1.05, height: size * 1.05)
                    .scaleEffect(0.8 + 0.45 * pulseProgress)
                    .opacity(max(0, 0.55 - 0.55 * pulseProgress))

                // Your circular asset (e.g., "profile_button")
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
            }
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .frame(width: size, height: size)           // hit target
            .contentShape(Circle())                     // circular hit test
            .accessibilityLabel(Text(accessibilityText))
        }
        .buttonStyle(.plain)
    }

    private var accessibilityText: String {
        switch imageName.lowercased() {
        case _ where imageName.contains("profile"):   return "Profile"
        case _ where imageName.contains("menu"):      return "Menu"
        case _ where imageName.contains("game"):      return "Mini Games"
        default:                                      return "Button"
        }
    }
}

#if DEBUG
struct CircularIconButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 24) {
            CircularIconButton(imageName: "profile_button") {}
            CircularIconButton(imageName: "hubmenu_button") {}
            CircularIconButton(imageName: "minigames_button") {}
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
