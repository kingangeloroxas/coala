//
//  MatchPair.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/4/25.
//


import Foundation

struct MatchPair {
    static func score(between user1: User, and user2: User) -> Int {
        var score = 0
        if user1.mbti == user2.mbti {
            score += 1
        }
        if user1.vibe == user2.vibe {
            score += 1
        }
        return score
    }
}
