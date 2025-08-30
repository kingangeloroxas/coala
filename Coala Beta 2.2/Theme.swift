//  Theme.swift
//  Coala Beta 2.2

import SwiftUI

// MARK: - Theme
enum Theme {
    static let corner: CGFloat  = 14
    static let spacing: CGFloat = 16

    static let gradient = LinearGradient(
        colors: [Color.brand, Color.brandAlt],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // MARK: - Coala Mascot Palette
    enum Coala {
        /// Dark outline color from mascot (stroke)
        static let outline = Color(red: 0.09, green: 0.27, blue: 0.55)
        /// Light fill color from mascot
        static let fill    = Color(red: 0.72, green: 0.88, blue: 1.00)
        /// Text color when on the light fill
        static let textOnFill = Color.white
    }
}

// MARK: - Color Assets
extension Color {
    static let brand    = Color("BrandBlue")     // must exist in Assets
    static let brandAlt = Color("BrandPurple")   // must exist in Assets
    static let surface  = Color(.secondarySystemBackground)
}
