//
//  Message.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/3/25.
//


import Foundation

struct Message: Identifiable {
    var id = UUID()
    var sender: String
    var text: String
    var timestamp: Date
}
