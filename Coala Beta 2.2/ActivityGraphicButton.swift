//
//  PressBounceStyle.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/23/25.
//


import SwiftUI

/// Press-down scale effect used by the button.
struct PressBounceStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// A clickable, animated image button with haptic feedback.
struct ActivityGraphicButton: View {
    var imageName: String = "activity_button"   // change to "activitiy_button" if that’s your asset name
    var accessibilityLabel: String = "Go to Activities"
    var action: () -> Void

    @State private var didFireHaptic = false

    var body: some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)   // keeps the card proportions
                .accessibilityLabel(accessibilityLabel)
                .contentShape(Rectangle())        // full image is tappable
        }
        .buttonStyle(PressBounceStyle())          // press bounce animation
        // Fire a light haptic as soon as the finger goes down.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !didFireHaptic {
                        didFireHaptic = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                .onEnded { _ in didFireHaptic = false }
        )
    }
}
