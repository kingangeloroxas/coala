//
//  Activity.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 7/18/25.
//


import Foundation

struct Activity: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
}
