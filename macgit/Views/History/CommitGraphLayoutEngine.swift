//
//  CommitGraphLayoutEngine.swift
//  macgit
//

import Foundation
import SwiftUI

enum CommitGraphLayoutEngine {
    /// Builds a lane/edge layout for commits assumed to be in reverse chronological
    /// order (newest first). Each commit's parents are resolved by hash; parents that
    /// are not present in `commits` (e.g. beyond `maxCount`) are dropped.
    static func layout(commits: [Commit]) -> CommitGraphLayout {
        struct PendingEdge {
            let fromRow: Int
            let fromLane: Int
            let parentID: String
            let isMergeParent: Bool
        }

        var activeLanes: [String?] = []           // per-lane: hash of expected next commit
        var nodes: [GraphNode] = []
        var positions: [String: (lane: Int, row: Int)] = [:]
        var pendingEdges: [PendingEdge] = []
        var maxLaneSeen = 0

        for (row, commit) in commits.enumerated() {
            var claimedLane: Int?
            for (idx, expected) in activeLanes.enumerated() where expected == commit.hash {
                if claimedLane == nil {
                    claimedLane = idx
                } else {
                    // Multiple lanes converge on this commit; clear the extras.
                    activeLanes[idx] = nil
                }
            }

            let lane: Int
            if let claimedLane {
                lane = claimedLane
            } else if let freeLane = activeLanes.firstIndex(of: nil) {
                lane = freeLane
            } else {
                lane = activeLanes.count
                activeLanes.append(nil)
            }

            nodes.append(GraphNode(commit: commit, lane: lane, rowIndex: row))
            positions[commit.hash] = (lane, row)
            maxLaneSeen = max(maxLaneSeen, lane + 1)

            if commit.parents.isEmpty {
                activeLanes[lane] = nil
            } else {
                // First parent inherits this lane to keep the main line straight;
                // extra parents (merges) spawn side lanes.
                activeLanes[lane] = commit.parents[0]
                pendingEdges.append(PendingEdge(fromRow: row, fromLane: lane, parentID: commit.parents[0], isMergeParent: false))

                for parent in commit.parents.dropFirst() {
                    let parentLane: Int
                    if let existingLane = activeLanes.firstIndex(of: parent) {
                        parentLane = existingLane
                    } else if let freeLane = activeLanes.firstIndex(of: nil) {
                        parentLane = freeLane
                        activeLanes[freeLane] = parent
                    } else {
                        parentLane = activeLanes.count
                        activeLanes.append(parent)
                    }
                    maxLaneSeen = max(maxLaneSeen, parentLane + 1)
                    // fromLane is the child's lane so the edge visibly starts from
                    // the merge node; toLane (the parent's lane) is resolved below.
                    pendingEdges.append(PendingEdge(fromRow: row, fromLane: lane, parentID: parent, isMergeParent: true))
                }
            }
        }

        // Edges are deferred until now because a parent may appear many rows
        // later and we need its final (row, lane) to draw the connector.
        var edges: [GraphEdge] = []
        for pending in pendingEdges {
            guard let parentPos = positions[pending.parentID] else { continue }
            edges.append(GraphEdge(
                fromRow: pending.fromRow,
                fromLane: pending.fromLane,
                toRow: parentPos.row,
                toLane: parentPos.lane,
                isMergeParent: pending.isMergeParent
            ))
        }

        return CommitGraphLayout(nodes: nodes, edges: edges, laneCount: max(1, maxLaneSeen))
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
