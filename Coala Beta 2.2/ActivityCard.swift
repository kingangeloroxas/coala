//
//  ActivityCard.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/11/25.
//


import SwiftUI

struct ActivityCard: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundColor(.brand)
                Text(title).bold()
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.brand)
                }
            }
            .padding()
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner)
                    .stroke(isSelected ? Color.brand : Color.black.opacity(0.08), lineWidth: 1)
            )
        }
    }
}
