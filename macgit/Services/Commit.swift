//
//  Commit.swift
//  macgit
//

import Foundation

struct Commit: Identifiable, Equatable {
    let id = UUID()
    let hash: String
    let parents: [String]
    let message: String
    let author: String
    let email: String
    let date: Date
    let refs: [String]
    
    var shortHash: String {
        String(hash.prefix(7))
    }
    
    var isMerge: Bool {
        parents.count > 1
    }
    
    static func == (lhs: Commit, rhs: Commit) -> Bool {
        lhs.hash == rhs.hash
    }
}

// MARK: - Commit File Change

struct CommitFileChange: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let status: CommitFileStatus
}

enum CommitFileStatus: String {
    case added = "A"
    case modified = "M"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    
    var displayText: String {
        switch self {
        case .added: return "Added"
        case .modified: return "Modified"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        }
    }
    
    var color: String {
        switch self {
        case .added: return "green"
        case .modified: return "orange"
        case .deleted: return "red"
        case .renamed: return "blue"
        case .copied: return "purple"
        }
    }
}
