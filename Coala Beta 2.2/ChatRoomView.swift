//
//  ChatRoomView.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/4/25.
//


import SwiftUI

struct ChatRoomView: View {
    var groupId: String

    var body: some View {
        VStack(spacing: 20) {
            Text("💬 Chat Room")
                .font(.largeTitle)
                .bold()

            Text("Group ID: \(groupId)")
                .foregroundColor(.gray)

            Spacer()
        }
        .padding()
    }
}
