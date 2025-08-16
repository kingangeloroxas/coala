//
//  AppTheme.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/11/25.
//


import SwiftUI

enum AppTheme {
    static let corner: CGFloat = 14
    static let spacing: CGFloat = 16

    static let gradient = LinearGradient(
        colors: [Color.brand, Color.brandAlt],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

extension Color {
    static let brand = Color("BrandBlue")     // add to Assets (or swap to .blue)
    static let brandAlt = Color("BrandPurple")// add to Assets (or swap to .purple)
    static let surface = Color(.secondarySystemBackground)
}
