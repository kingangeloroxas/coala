//
//  SplashView.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 7/18/25.
//

import SwiftUI

struct SplashView: View {
    /// Called when the user taps anywhere (navigate to .onboarding in ContentView)
    var onStart: () -> Void

    @State private var animate = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            GeometryReader { geo in
                Image("coala_logo") // Ensure this exists in your Assets
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width - 48)
                    .padding(.horizontal, 24)
                    .scaleEffect(animate ? 1.0 : 0.9)
                    .opacity(animate ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6), value: animate)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .contentShape(Rectangle()) // Make the entire view tappable
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onStart()
        }
        .onAppear { animate = true }
        .navigationBarBackButtonHidden(true)
    }
}

