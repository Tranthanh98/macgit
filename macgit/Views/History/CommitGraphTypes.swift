//
//  CommitGraphTypes.swift
//  macgit
//

import SwiftUI

nonisolated enum CommitGraphHighlighting: Equatable, Sendable {
    case all
    case currentBranchOnly
}

nonisolated struct GraphCommitMetadata: Sendable {
    let colorIndex: Int
    let isHighlighted: Bool
    let leftMargin: Double
}

nonisolated struct GraphPath: Sendable {
    let points: [CGPoint]
    let colorIndex: Int
    let isHighlighted: Bool
}

nonisolated struct GraphLink: Sendable {
    let start: CGPoint
    let control: CGPoint
    let end: CGPoint
    let colorIndex: Int
    let isHighlighted: Bool
}

nonisolated enum GraphDotType: Equatable, Sendable {
    case `default`
    case head
    case merge
}

nonisolated struct GraphDot: Sendable {
    let center: CGPoint
    let lane: Int
    let type: GraphDotType
    let colorIndex: Int
    let isHighlighted: Bool
}

nonisolated struct CommitGraphModel: Sendable {
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
