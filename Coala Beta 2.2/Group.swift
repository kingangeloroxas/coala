//
//  Group.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/3/25.
//


import Foundation

struct Group: Identifiable {
    var id = UUID()
    var activity: String
    var groupSize: Int
    var matchedUserNames: [String]
    var vibe: String
    var topBranch: String?
    var status: String // "locked" or "forming"

    var planDate: String?
    var planTime: String?
    var planLocation: String?
    var planNote: String?
}
