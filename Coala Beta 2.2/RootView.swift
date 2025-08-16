//
//  RootView.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/4/25.
//


import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ContentView()
            .environmentObject(appState)
    }
}
