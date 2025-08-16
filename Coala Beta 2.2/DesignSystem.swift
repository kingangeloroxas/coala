//
//  DesignSystem.swift
//  Coala
//

import SwiftUI

// MARK: - Theme (spacing, corners, colors, typography)

enum DS {
    // Layout
    static let corner: CGFloat = 14
    static let spacing: CGFloat = 16

    // Colors (swap to asset colors later if you want)
    static let brand: Color = .blue
    static let brandAlt: Color = .purple
    static let surface: Color = Color(.secondarySystemBackground)

    static var gradient: LinearGradient {
        LinearGradient(colors: [brand, brandAlt], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Optional: set native bar appearance once
    static func configureAppearance() {
        #if canImport(UIKit)
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor.systemBackground
        nav.titleTextAttributes = [.foregroundColor: UIColor.label]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor.systemBackground
        UITabBar.appearance().standardAppearance = tab
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tab
        }
        #endif
    }
}

// MARK: - Typography

enum DSTypography {
    static var titleXL: Font { .system(.largeTitle, design: .rounded).weight(.bold) }
    static var titleL:  Font { .system(size: 28, weight: .bold, design: .rounded) }
    static var titleM:  Font { .title2.weight(.semibold) }
    static var body:    Font { .body }
    static var cta:     Font { .headline }
    static var chip:    Font { .subheadline.weight(.semibold) }
}

// MARK: - Global text-input helper (optional)

/// If you ever want to apply “no autocap / no autocorrect” per-field,
/// you can call `.appTextFieldStyle()` on any TextField/SecureField.
/// (You don’t *need* this if you use the App-wide environment below.)
struct NoAutoCapModifier: ViewModifier {
    var keyboardType: UIKeyboardType = .default
    func body(content: Content) -> some View {
        content
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never) // iOS 15+
            .autocorrectionDisabled(true)
    }
}
extension View {
    func appTextFieldStyle(keyboardType: UIKeyboardType = .default) -> some View {
        self.modifier(NoAutoCapModifier(keyboardType: keyboardType))
    }
}

// MARK: - Reusable Components

// 1) Primary CTA Button Style
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSTypography.cta)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(DS.gradient.opacity(configuration.isPressed ? 0.85 : 1))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.corner, style: .continuous))
            .shadow(color: .black.opacity(configuration.isPressed ? 0.08 : 0.18),
                    radius: 12, y: 6)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// 2) TextField visual style (keeps visuals consistent app-wide)
struct AppTextField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.corner, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
    }
}
extension View { func appTextField() -> some View { modifier(AppTextField()) } }

// 3) SelectableChip (for MBTI/Vibe/Activities)
struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(DSTypography.chip)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").font(DSTypography.chip)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minWidth: 84)
            .foregroundColor(isSelected ? .white : .primary)
            .background(isSelected ? DS.brand : DS.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .contentShape(Capsule())
    }
}

// 4) PillButton (great for group size)
struct PillButton: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DSTypography.cta)
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .foregroundColor(isSelected ? .white : .primary)
                .background(isSelected ? DS.brand : DS.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.black.opacity(0.08), lineWidth: 1)
                )
        }
        .contentShape(Capsule())
    }
}


struct TopBar: View {
    var title: String
    var onBack: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Back button layer
            HStack {
                if let onBack = onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                            .contentShape(Rectangle())
                    }
                    .padding(.leading, 16)
                }
                Spacer()
            }

            // Centered title
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
                // Keep some side padding so title never overlaps the back button
                .padding(.horizontal, 60)
        }
        .frame(height: 48)
        .background(Color.clear)
    }
}
