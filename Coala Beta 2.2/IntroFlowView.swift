//
//  IntroFlowView.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/18/25.
//

import SwiftUI
import UIKit

struct IntroFlowView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("hasSeenIntro") private var hasSeenIntro: Bool = false

    @State private var pageIndex: Int = 0
    private let chevronBlue = Color(red: 0.60, green: 0.80, blue: 0.96)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // Pages
            SwiftUI.Group {
                if pageIndex == 0 {
                    IntroScreenOne().id(0)
                } else {
                    IntroScreenTwo().id(1)
                }
            }
        }
        // Keep the Next chevron fixed and unsquished
        .overlay(alignment: .bottomTrailing) {
            NextArrowButton(
                color: chevronBlue,
                onTap: {
                    if pageIndex == 0 {
                        withAnimation(.easeOut(duration: 0.2)) { pageIndex = 1 }
                    } else {
                        finishIntro()
                    }
                }
            )
            .padding(.trailing, 20)
            .padding(.bottom, 16)
        }
        .onAppear { FontLogger.logAllFonts() }
    }

    private func finishIntro() {
        hasSeenIntro = true
        appState.goToOnboarding()
    }
}

// MARK: - Screen 1 (STRICTLY contained image inside safe area)

private struct IntroScreenOne: View {
    @State private var isVisible = false

    var body: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let horizontalMargin: CGFloat = 16
            let topMargin: CGFloat = 8
            let chevronReserve: CGFloat = 64

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.93, green: 0.98, blue: 1.00),
                             Color(red: 0.86, green: 0.96, blue: 1.00)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                Image("coalatip1")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: geo.size.width
                                  - (insets.leading + insets.trailing)
                                  - (horizontalMargin * 2),
                        maxHeight: geo.size.height
                                   - (insets.top + insets.bottom)
                                   - topMargin
                                   - chevronReserve
                    )
                    .padding(.top, insets.top + topMargin)
                    .padding(.horizontal, insets.leading + horizontalMargin)
                    .accessibilityLabel("Coala tip sheet 1")
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    .opacity(isVisible ? 1 : 0)
                    .animation(.easeIn(duration: 2.0), value: isVisible)
                    .onAppear { isVisible = true }
            }
        }
    }
}

// MARK: - Screen 2 (IDENTICAL LAYOUT; different asset: coalatip2)

private struct IntroScreenTwo: View {
    @State private var isVisible = false

    var body: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let horizontalMargin: CGFloat = 16
            let topMargin: CGFloat = 8
            let chevronReserve: CGFloat = 64

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.93, green: 0.98, blue: 1.00),
                             Color(red: 0.86, green: 0.96, blue: 1.00)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                Image("coalatip2")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: geo.size.width
                                  - (insets.leading + insets.trailing)
                                  - (horizontalMargin * 2),
                        maxHeight: geo.size.height
                                   - (insets.top + insets.bottom)
                                   - topMargin
                                   - chevronReserve
                    )
                    .padding(.top, insets.top + topMargin)
                    .padding(.horizontal, insets.leading + horizontalMargin)
                    .accessibilityLabel("Coala tip sheet 2")
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    .opacity(isVisible ? 1 : 0)
                    .animation(.easeIn(duration: 2.0), value: isVisible)
                    .onAppear { isVisible = true }
            }
        }
    }
}

// MARK: - Chevron

private struct NextArrowButton: View {
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "chevron.right")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
                .frame(width: 48, height: 48, alignment: .center)
                .contentShape(Rectangle())
                .accessibilityLabel("Next")
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Font Logger (optional debug)

private enum FontLogger {
    static func logAllFonts() {
        #if DEBUG
        print("==== Loaded font families & names ====")
        for family in UIFont.familyNames.sorted() {
            print("Family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family).sorted() {
                print("  \(name)")
            }
        }
        print("======================================")
        #endif
    }
}

