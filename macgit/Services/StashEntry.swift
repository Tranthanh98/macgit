//
//  StashEntry.swift
//  macgit
//

import Foundation

struct StashEntry: Identifiable, Hashable {
    var id: String { ref }

    let ref: String
    let branchName: String
    let description: String

    var displayTitle: String {
        "On \(branchName) : \(description)"
    }
}
