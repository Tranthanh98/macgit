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

// MARK: - SourceGit-aligned Graph Types

/// Namespace for the new sourcegit-aligned graph model types.
///
/// These types are intentionally nested here so they can coexist with the
/// legacy top-level graph types (`GraphNode`, `GraphPath`, `GraphPoint`,
/// `CommitGraphLayout`, `LaneColors`) while the rewrite proceeds. Once the
/// legacy layout engine and views are replaced, this namespace can be removed
/// and the types promoted to top-level.
enum SourceGit {

    enum CommitGraphHighlighting {
        case all
        case currentBranchOnly
    }

    struct GraphCommitMetadata {
        let colorIndex: Int
        let isHighlighted: Bool
        let leftMargin: Double
    }

    struct GraphPath {
        let points: [CGPoint]
        let colorIndex: Int
        let isHighlighted: Bool
    }

    struct GraphLink {
        let start: CGPoint
        let control: CGPoint
        let end: CGPoint
        let colorIndex: Int
        let isHighlighted: Bool
    }

    enum GraphDotType {
        case `default`
        case head
        case merge
    }

    struct GraphDot {
        let center: CGPoint
        let lane: Int
        let type: GraphDotType
        let colorIndex: Int
        let isHighlighted: Bool
    }

    struct CommitGraphModel {
        let paths: [GraphPath]
        let links: [GraphLink]
        let dots: [GraphDot]
        let laneCount: Int
        let commitMetadata: [String: GraphCommitMetadata]
    }

    struct GraphPalette {
        static let colors: [Color] = [
            Color(nsColor: .systemOrange),
            Color(nsColor: .systemGreen),
            Color(nsColor: .systemTeal),
            Color(nsColor: .systemYellow),
            Color(nsColor: .systemPink),
            Color(nsColor: .systemRed),
            Color(nsColor: .systemBrown),
            Color(nsColor: .systemGreen),
            Color(nsColor: .systemBlue),
            Color(nsColor: .systemCyan),
        ]

        static func color(for index: Int) -> Color {
            colors[index % colors.count]
        }
    }
}
