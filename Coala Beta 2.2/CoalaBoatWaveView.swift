//
//  SineWave.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/26/25.
//

import SwiftUI

// MARK: - Reusable sine-wave Shape
fileprivate struct BoatWaveShape: Shape {
    var amplitude: CGFloat     // wave height
    var frequency: CGFloat     // waves across width (cycles)
    var phase: CGFloat         // horizontal shift (animated)

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.midY

        p.move(to: CGPoint(x: 0, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0, y: midY))

        // draw the sine curve
        for x in stride(from: 0, through: rect.width, by: 1) {
            let progress = x / rect.width
            let y = midY + amplitude * sin(progress * frequency * .pi * 2 + phase)
            p.addLine(to: CGPoint(x: x, y: y))
        }

        p.addLine(to: CGPoint(x: rect.width, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Main Component
public struct CoalaBoatWaveViewV2: View {
    public var duration: Double = 5.0
    public var onCompleted: (() -> Void)? = nil

    // Tunables
    var boatImageName: String = "coala_boat"
    var skyTop = Color(red: 0.90, green: 0.97, blue: 1.00)
    var skyBottom = Color.white
    var wave1Color = Color(red: 0.39, green: 0.62, blue: 0.96).opacity(0.55)
    var wave2Color = Color(red: 0.20, green: 0.45, blue: 0.86).opacity(0.75)

    var waveHeight: CGFloat = 120
    var amplitude1: CGFloat = 12
    var amplitude2: CGFloat = 16
    var frequency: CGFloat = 1.8
    var speed: Double = 2.2       // seconds per cycle
    var bobAmplitude: CGFloat = 10 // boat bobbing in points
    var tiltDegrees: CGFloat = 3.5 // subtle rocking

    // Animation state (explicit phase-driven)
    @State private var startTime: Date? = nil
    @State private var didComplete: Bool = false

    public var body: some View {
        TimelineView(.animation) { context in
            let now = context.date
            let start = startTime ?? now
            let elapsed = max(0, now.timeIntervalSince(start))
            let clamped = min(elapsed, duration)
            let phaseVal = CGFloat((clamped / speed) * (2.0 * .pi))

            GeometryReader { geo in
                ZStack {
                    // Background sky
                    LinearGradient(colors: [skyTop, skyBottom],
                                   startPoint: .top,
                                   endPoint: .bottom)
                    .ignoresSafeArea()

                    // BIG pulsing headline at the very top
                    let titlePulse = 1.0 + 0.06 * sin(phaseVal * 1.2)
                    VStack {
                        Text("finding your co-venturers")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 0.09, green: 0.27, blue: 0.55))
                            .scaleEffect(titlePulse)
                            .padding(.top, 24)
                        Spacer()
                    }
                    .zIndex(4)

                    // Waves area pinned to bottom
                    VStack {
                        Spacer(minLength: 0)
                        ZStack {
                            // Back wave (slower)
                            BoatWaveShape(amplitude: amplitude1,
                                          frequency: frequency,
                                          phase: phaseVal * 0.9)
                                .fill(wave1Color)
                                .frame(height: waveHeight)

                            // Front wave (faster, slight phase offset)
                            BoatWaveShape(amplitude: amplitude2,
                                          frequency: frequency * 1.15,
                                          phase: phaseVal + 1.2)
                                .fill(wave2Color)
                                .frame(height: waveHeight)
                                .offset(y: 8)
                        }
                        .compositingGroup()
                        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: -2)
                        .zIndex(1)
                    }

                    // Boat sits just above the wave crest and bobs/rocks with the same phase
                    Image(boatImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(240, geo.size.width * 0.55))
                        .offset(y: boatVerticalOffset(in: geo.size, phase: phaseVal))
                        .rotationEffect(.degrees(rockAngle(phase: phaseVal)))
                        .padding(.bottom, waveHeight * 0.35)
                        .zIndex(2)
                        .accessibilityLabel("Coala boat sailing on waves")

                    // Center overlay message with pulse tied to phase
                    let pulse = 0.7 + 0.3 * (0.5 + 0.5 * sin(phaseVal * 0.8))
                    VStack {
                        Text("Finding your crew…")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 0.09, green: 0.27, blue: 0.55))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.85))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                            .opacity(pulse)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(3)
                }
                .onAppear {
                    if startTime == nil { startTime = now }
                    // schedule completion once after `duration`
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        if !didComplete {
                            didComplete = true
                            onCompleted?()
                        }
                    }
                }
            }
        }
        .clipped()
    }

    // MARK: - Helpers
    private func boatVerticalOffset(in size: CGSize, phase: CGFloat) -> CGFloat {
        // place boat above bottom waves + bobbing
        let baseline = size.height * 0.30
        let bob = -bobAmplitude * sin(phase) // negative lifts the boat slightly
        return (size.height / 2 - baseline) + bob
    }

    private func rockAngle(phase: CGFloat) -> Double {
        // small alternating tilt synced to bobbing
        Double(tiltDegrees * sin(phase + .pi/2))
    }
}

// MARK: - Preview
struct CoalaBoatWaveViewV2_Previews: PreviewProvider {
    static var previews: some View {
        CoalaBoatWaveViewV2()
            .frame(height: 500)
            .previewDisplayName("Coala Boat Waves")
    }
}
