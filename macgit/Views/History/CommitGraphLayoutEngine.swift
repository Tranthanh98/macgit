//
//  CommitGraphLayoutEngine.swift
//  macgit
//

import Foundation

struct CommitGraphLayoutEngine {
    static func layout(commits: [Commit]) -> [GraphNode] {
        guard !commits.isEmpty else { return [] }
        
        var commitByHash: [String: Commit] = [:]
        var childrenOf: [String: [String]] = [:]
        
        for commit in commits {
            commitByHash[commit.hash] = commit
            for parent in commit.parents {
                childrenOf[parent, default: []].append(commit.hash)
            }
        }
        
        // Assign lanes top-to-bottom (newest first)
        var commitLane: [String: Int] = [:]
        var nextLane = 0
        
        for commit in commits {
            let hash = commit.hash
            let children = childrenOf[hash, default: []]
            let placedChildren = children.filter { commitLane[$0] != nil }
            let primaryChildren = placedChildren.filter {
                commitByHash[$0]?.parents.first == hash
            }
            
            if let primary = primaryChildren.sorted(by: {
                commitLane[$0]! < commitLane[$1]!
            }).first {
                commitLane[hash] = commitLane[primary]!
            } else if placedChildren.isEmpty {
                commitLane[hash] = nextLane
                nextLane += 1
            } else {
                // Secondary parent of a merge → new lane
                commitLane[hash] = nextLane
                nextLane += 1
            }
        }
        
        // Build GraphNodes
        var nodes: [GraphNode] = []
        for commit in commits {
            let children = childrenOf[commit.hash, default: []]
            let parentLanes = commit.parents.compactMap { commitLane[$0] }
            let childLanes = children.compactMap { commitLane[$0] }
            let currentLane = commitLane[commit.hash] ?? 0
            
            var mergeSources: [Int] = []
            if parentLanes.count > 1 {
                mergeSources = parentLanes.filter { $0 != currentLane }
            }
            
            let node = GraphNode(
                commit: commit,
                lane: currentLane,
                laneOut: childLanes,
                mergeSourceLanes: mergeSources,
                isLaneEnd: children.isEmpty
            )
            nodes.append(node)
        }
        
        return nodes
    }
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

import SwiftUI
