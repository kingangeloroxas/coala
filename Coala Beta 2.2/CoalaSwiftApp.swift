//
//  CoalaSwiftApp.swift
//  Coala
//

import SwiftUI

@main
struct CoalaSwiftApp: App {
    @StateObject private var appState = AppState()

    init() {
        DS.configureAppearance() // optional bar styling
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                // Global app styling:
                .tint(DS.brand)
                .environment(\.font, DSTypography.body)
                // 🔴 GLOBAL INPUT BEHAVIOR (affects ALL TextField/SecureField underneath)
                .textInputAutocapitalization(.never)   // iOS 15+
                .autocorrectionDisabled(true)
                // .preferredColorScheme(.light) // uncomment to force light mode
        }
    }
}

