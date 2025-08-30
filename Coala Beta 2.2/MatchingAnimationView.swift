import SwiftUI

// MARK: - Reusable sine-wave Shape
struct SineWave: Shape {
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
struct CoalaBoatWaveView: View {
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

    // Animation state
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background sky
                LinearGradient(colors: [skyTop, skyBottom],
                               startPoint: .top,
                               endPoint: .bottom)
                .ignoresSafeArea()

                // Waves area pinned to bottom
                VStack {
                    Spacer(minLength: 0)
                    ZStack {
                        // Back wave (slower)
                        SineWave(amplitude: amplitude1,
                                 frequency: frequency,
                                 phase: phase * 0.9)
                            .fill(wave1Color)
                            .frame(height: waveHeight)

                        // Front wave (faster, slight phase offset)
                        SineWave(amplitude: amplitude2,
                                 frequency: frequency * 1.15,
                                 phase: phase + 1.2)
                            .fill(wave2Color)
                            .frame(height: waveHeight)
                            .offset(y: 8)
                    }
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: -2)
                }

                // Boat sits just above the wave crest and bobs
                Image(boatImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(240, geo.size.width * 0.55))
                    .offset(y: boatVerticalOffset(in: geo.size))
                    .rotationEffect(.degrees(rockAngle))
                    .accessibilityLabel("Coala boat sailing on waves")
            }
            .onAppear {
                // Continuous phase advance for the waves
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
        }
        .clipped()
    }

    // MARK: - Helpers
    private func boatVerticalOffset(in size: CGSize) -> CGFloat {
        // place boat above bottom waves + bobbing
        let baseline = size.height * 0.30
        let bob = -bobAmplitude * sin(phase) // negative lifts the boat slightly
        return (size.height / 2 - baseline) + bob
    }

    private var rockAngle: Double {
        // small alternating tilt synced to bobbing
        Double(tiltDegrees * sin(phase + .pi/2))
    }
}

// MARK: - Preview
struct CoalaBoatWaveView_Previews: PreviewProvider {
    static var previews: some View {
        CoalaBoatWaveView()
            .frame(height: 500)
            .previewDisplayName("Coala Boat Waves")
    }
}
