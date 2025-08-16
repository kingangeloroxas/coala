//
//  FlowLayout.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/11/25.
//


import SwiftUI

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content

    init(items: Data, spacing: CGFloat = 8, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            var x: CGFloat = 0
            var y: CGFloat = 0

            ZStack(alignment: .topLeading) {
                ForEach(items, id: \.self) { item in
                    content(item)
                        .alignmentGuide(.leading) { d in
                            if x + d.width > geo.size.width {
                                x = 0
                                y -= d.height + spacing
                            }
                            let result = x
                            x += d.width + spacing
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = y
                            return result
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
