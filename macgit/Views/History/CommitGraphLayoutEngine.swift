//
//  CommitGraphLayoutEngine.swift
//  macgit
//

import Foundation
import SwiftUI

enum CommitGraphLayoutEngine {
    /// Builds a lane/edge layout for commits assumed to be in reverse chronological
    /// order (newest first). Each commit's parents are resolved by hash; parents that
    /// are not present in `commits` (e.g. beyond `maxCount`) become placeholder
    /// vertices so merge connectors can still be drawn.
    static func layout(commits: [Commit]) -> CommitGraphLayout {
        guard !commits.isEmpty else {
            return CommitGraphLayout(nodes: [], paths: [], laneCount: 1)
        }

        // Phase 1: build vertices
        var vertices = buildVertices(commits: commits)

        // Phase 2: assign branches
        let branches = assignBranches(vertices: &vertices)

        // Phase 3: route paths
        let paths = routePaths(vertices: vertices, branches: branches)

        // Build public nodes
        let nodes = vertices.enumerated().compactMap { (row, vertex) -> GraphNode? in
            guard let commit = vertex.commit else { return nil }
            return GraphNode(commit: commit, lane: vertex.lane, rowIndex: row)
        }

        let laneCount = (vertices.map(\.lane).max() ?? 0) + 1

        return CommitGraphLayout(nodes: nodes, paths: paths, laneCount: laneCount)
    }

    // MARK: - Phase 1: Vertex Graph

    private static func buildVertices(commits: [Commit]) -> [Vertex] {
        var rowByHash: [String: Int] = [:]
        for (row, commit) in commits.enumerated() {
            rowByHash[commit.hash] = row
        }

        var vertices: [Vertex] = []
        var placeholderRows: [String: Int] = [:]

        func placeholderRow(for hash: String) -> Int {
            if let row = placeholderRows[hash] { return row }
            let row = commits.count + placeholderRows.count
            placeholderRows[hash] = row
            return row
        }

        for (row, commit) in commits.enumerated() {
            let parentRows = commit.parents.map { rowByHash[$0] ?? placeholderRow(for: $0) }
            vertices.append(Vertex(row: row, commit: commit, parentRows: parentRows, childRows: []))
        }

        let sortedPlaceholders = placeholderRows.sorted { $0.value < $1.value }
        for (_, row) in sortedPlaceholders {
            vertices.append(Vertex(row: row, commit: nil, parentRows: [], childRows: []))
        }

        for (row, _) in commits.enumerated() {
            for parentRow in vertices[row].parentRows {
                vertices[parentRow].childRows.append(row)
            }
        }

        return vertices
    }

    // MARK: - Phase 2: Branch Assignment

    private static func assignBranches(vertices: inout [Vertex]) -> [Branch] {
        var branches: [Branch] = []
        var colorPool = BranchColorPool()

        for row in 0..<vertices.count {
            let vertex = vertices[row]
            guard vertex.commit != nil else { continue }
            guard vertex.branchID == nil else { continue }

            let branch = Branch(id: branches.count, color: colorPool.allocate(), startRow: row)
            branch.vertices.append(vertex)
            vertices[row].branchID = branch.id
            branches.append(branch)

            var currentRow = row
            while true {
                let current = vertices[currentRow]
                guard let nextParentRow = firstParentRow(for: current) else {
                    branch.endRow = currentRow
                    break
                }

                guard nextParentRow != currentRow else {
                    branch.endRow = currentRow
                    break
                }

                let parent = vertices[nextParentRow]
                if parent.branchID != nil {
                    branch.endRow = currentRow
                    break
                }

                vertices[nextParentRow].branchID = branch.id
                branch.vertices.append(parent)
                branch.endRow = nextParentRow
                currentRow = nextParentRow
            }
        }

        return branches
    }

    private static func firstParentRow(for vertex: Vertex) -> Int? {
        guard !vertex.parentRows.isEmpty else { return nil }
        return vertex.parentRows[0]
    }

    // MARK: - Phase 3: Path Routing

    private static func routePaths(vertices: [Vertex], branches: [Branch]) -> [GraphPath] {
        var paths: [GraphPath] = []

        for branch in branches {
            // Main branch path
            var points: [GraphPoint] = []
            for row in branch.startRow...branch.endRow {
                points.append(GraphPoint(row: row, lane: vertices[row].lane))
            }
            if points.count > 1 {
                paths.append(GraphPath(points: points, color: branch.color, isMergeConnector: false))
            }

            // Merge connectors
            for vertex in branch.vertices {
                guard vertex.parentRows.count > 1 else { continue }
                for parentRow in vertex.parentRows.dropFirst() {
                    let parent = vertices[parentRow]
                    let parentBranch = parent.branchID.map { branches[$0] }
                    let parentLane = parentBranch?.id ?? branch.id
                    var connectorPoints: [GraphPoint] = []
                    for row in vertex.row...parentRow {
                        let lane = row == vertex.row ? vertex.lane : parentLane
                        connectorPoints.append(GraphPoint(row: row, lane: lane))
                    }
                    if connectorPoints.count > 1 {
                        let color = parentBranch?.color ?? branch.color
                        paths.append(GraphPath(points: connectorPoints, color: color, isMergeConnector: true))
                    }
                }
            }
        }

        return paths
    }
}

// MARK: - Internal Layout Types

private final class Branch {
    let id: Int
    let color: Color
    var startRow: Int
    var endRow: Int
    var vertices: [Vertex] = []

    init(id: Int, color: Color, startRow: Int) {
        self.id = id
        self.color = color
        self.startRow = startRow
        self.endRow = startRow
    }
}

private final class Vertex {
    let row: Int
    let commit: Commit?
    var parentRows: [Int]
    var childRows: [Int]
    var branchID: Int?

    init(row: Int, commit: Commit?, parentRows: [Int], childRows: [Int], branchID: Int? = nil) {
        self.row = row
        self.commit = commit
        self.parentRows = parentRows
        self.childRows = childRows
        self.branchID = branchID
    }

    var lane: Int { branchID ?? 0 }
    var isMerge: Bool { parentRows.count > 1 }
}

private struct BranchColorPool {
    private let palette = LaneColors.palette
    private var nextColorIndex = 0

    mutating func allocate() -> Color {
        let color = palette[nextColorIndex % palette.count]
        nextColorIndex += 1
        return color
    }
}
