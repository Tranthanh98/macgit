//
//  CommitGraphTypes.swift
//  macgit
//

import SwiftUI

struct GraphNode: Identifiable {
    let id = UUID()
    let commit: Commit
    let lane: Int
    let rowIndex: Int
}

struct GraphPoint: Equatable {
    let row: Int
    let lane: Int
}

struct GraphPath {
    let points: [GraphPoint]
    let color: Color
    let isMergeConnector: Bool
}

struct CommitGraphLayout {
    let nodes: [GraphNode]
    let paths: [GraphPath]
    let laneCount: Int
}

// MARK: - Lane Colors

struct LaneColors {
    static let palette: [Color] = [
        Color(nsColor: NSColor.systemBlue),
        Color(nsColor: NSColor.systemGreen),
        Color(nsColor: NSColor.systemOrange),
        Color(nsColor: NSColor.systemPurple),
        Color(nsColor: NSColor.systemRed),
        Color(nsColor: NSColor.systemTeal),
        Color(nsColor: NSColor.systemYellow),
        Color(nsColor: NSColor.systemPink),
        Color(nsColor: NSColor.systemIndigo),
        Color(nsColor: NSColor.systemBrown),
    ]

    static func color(for lane: Int) -> Color {
        palette[lane % palette.count]
    }
}
