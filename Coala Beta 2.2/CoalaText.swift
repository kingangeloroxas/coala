//
//  BrandPalette.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/18/25.
//


import SwiftUI
import UIKit

// MARK: - Brand colors (use your assets if you have them)
enum BrandPalette {
    // Swap these to your asset colors if you’ve defined them:
    static let outline = Color(red: 0.05, green: 0.24, blue: 0.55)   // deep blue
    static let fill    = Color(red: 0.67, green: 0.84, blue: 1.00)   // light sky
}

// MARK: - OutlinedText (UIKit under the hood so we can use stroke)
struct OutlinedText: UIViewRepresentable {
    var text: String
    var size: CGFloat
    var weight: UIFont.Weight = .heavy
    var fill: UIColor = UIColor(BrandPalette.fill)
    var stroke: UIColor = UIColor(BrandPalette.outline)
    var strokeWidth: CGFloat = 8  // visual outline width

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = false
        label.backgroundColor = .clear
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        // Rounded system font to match the bubbly look
        var font = UIFont.systemFont(ofSize: size, weight: weight)
        if let rounded = font.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: rounded, size: size)
        }

        let attr = NSMutableAttributedString(string: text)
        // NOTE: Negative strokeWidth = fill + stroke. Positive = stroke only.
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: fill,
            .strokeColor: stroke,
            .strokeWidth: -strokeWidth
        ]
        attr.addAttributes(attrs, range: NSRange(location: 0, length: attr.length))
        uiView.attributedText = attr
    }
}

// MARK: - Convenience SwiftUI wrapper with subtle shine + shadow to match your logo
struct CoalaText: View {
    var _text: String
    var size: CGFloat = 72
    var body: some View {
        ZStack {
            // Outline + fill
            OutlinedText(text: _text, size: size)
                .shadow(color: BrandPalette.outline.opacity(0.12), radius: 8, y: 6)

            // Soft top-left highlight (like the logo shine)
            LinearGradient(
                colors: [Color.white.opacity(0.35), .clear],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .mask(
                OutlinedText(text: _text, size: size, fill: .white, stroke: .clear, strokeWidth: 0)
            )
            .allowsHitTesting(false)
        }
        .accessibilityLabel(_text)
    }
}

// MARK: - Quick previews / usage
struct CoalaText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            CoalaText(_text: "Coala", size: 88)
            CoalaText(_text: "go on co-ventures.", size: 40)
            CoalaText(_text: "Hello, world!", size: 64)
        }
        .padding()
        .background(Color.white)
        .previewLayout(.sizeThatFits)
    }
}
