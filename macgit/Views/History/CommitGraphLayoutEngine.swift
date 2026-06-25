//
//  CommitGraphLayoutEngine.swift
//  macgit
//

import Foundation
import SwiftUI

enum CommitGraphGenerator {
    private static let unitWidth = 12.0
    private static let halfWidth = 6.0
    private static let unitHeight = 1.0
    private static let halfHeight = 0.5
    private static let firstLaneX = 10.0

    static func generate(
        commits: [Commit],
        highlighting: SourceGit.CommitGraphHighlighting,
        headHash: String?
    ) -> SourceGit.CommitGraphModel {
        guard !commits.isEmpty else {
            return SourceGit.CommitGraphModel(
                paths: [],
                links: [],
                dots: [],
                laneCount: 1,
                commitMetadata: [:]
            )
        }

        let rowByHash = Dictionary(
            uniqueKeysWithValues: commits.enumerated().map { ($0.element.hash, $0.offset) }
        )
        let currentBranchCommits = reachableCommits(
            from: headHash,
            commits: commits,
            rowByHash: rowByHash
        )

        var mutablePaths: [MutableGraphPath] = []
        var links: [SourceGit.GraphLink] = []
        var dots: [SourceGit.GraphDot] = []
        var metadata: [String: SourceGit.GraphCommitMetadata] = [:]
        var unsolved: [PathHelper] = []
        var ended: [PathHelper] = []
        var offsetY = -halfHeight
        var colorPicker = ColorPicker(colorCount: SourceGit.GraphPalette.colors.count)
        var maxLane = 0

        for commit in commits {
            var major: PathHelper?
            offsetY += unitHeight

            var offsetX = 4 - halfWidth
            let maxOffsetOld = unsolved.last?.lastX ?? offsetX + unitWidth
            var isHighlighted = false

            for path in unsolved {
                if path.next == commit.hash {
                    if major == nil {
                        offsetX += unitWidth
                        major = path
                        isHighlighted = path.isHighlighted

                        if let firstParent = commit.parents.first {
                            path.next = firstParent
                            path.go(toX: offsetX, y: offsetY, halfHeight: halfHeight)
                        } else {
                            path.end(atX: offsetX, y: offsetY, halfHeight: halfHeight)
                            ended.append(path)
                        }
                    } else if let major {
                        path.end(atX: major.lastX, y: offsetY, halfHeight: halfHeight)
                        ended.append(path)
                        isHighlighted = isHighlighted || path.isHighlighted
                    }
                } else {
                    offsetX += unitWidth
                    path.pass(x: offsetX, y: offsetY, halfHeight: halfHeight)
                }
            }

            if !ended.isEmpty {
                let endedIDs = Set(ended.map(ObjectIdentifier.init))
                for path in ended {
                    colorPicker.recycle(path.colorIndex)
                }
                unsolved.removeAll { endedIDs.contains(ObjectIdentifier($0)) }
                ended.removeAll(keepingCapacity: true)
            }

            if !isHighlighted {
                switch highlighting {
                case .all:
                    isHighlighted = true
                case .currentBranchOnly:
                    isHighlighted = currentBranchCommits.contains(commit.hash)
                }
            }

            if major == nil {
                offsetX += unitWidth
                if let firstParent = commit.parents.first {
                    let path = PathHelper(
                        next: firstParent,
                        isHighlighted: isHighlighted,
                        colorIndex: colorPicker.next(),
                        start: CGPoint(x: offsetX, y: offsetY)
                    )
                    unsolved.append(path)
                    mutablePaths.append(path.path)
                    major = path
                }
            } else if let major,
                      isHighlighted,
                      !major.isHighlighted,
                      !commit.parents.isEmpty {
                let highlightedPath = major.highlight()
                mutablePaths.append(highlightedPath)
            }

            let position = CGPoint(x: major?.lastX ?? offsetX, y: offsetY)
            let dotColor = major?.colorIndex ?? 0
            let dotLane = lane(forX: position.x)
            maxLane = max(maxLane, dotLane)

            let dotType: SourceGit.GraphDotType
            if commit.hash == headHash || commit.refs.contains(where: {
                $0 == "HEAD" || $0.hasPrefix("HEAD -> ")
            }) {
                dotType = .head
            } else if commit.parents.count > 1 {
                dotType = .merge
            } else {
                dotType = .default
            }

            dots.append(
                SourceGit.GraphDot(
                    center: position,
                    lane: dotLane,
                    type: dotType,
                    colorIndex: dotColor,
                    isHighlighted: isHighlighted
                )
            )

            var pathByNext: [String: PathHelper] = [:]
            for path in unsolved where pathByNext[path.next] == nil {
                pathByNext[path.next] = path
            }

            for parentHash in commit.parents.dropFirst() {
                if let parent = pathByNext[parentHash] {
                    if isHighlighted && !parent.isHighlighted {
                        parent.go(
                            toX: parent.lastX,
                            y: offsetY + halfHeight,
                            halfHeight: halfHeight
                        )
                        let highlightedPath = parent.highlight()
                        mutablePaths.append(highlightedPath)
                    }

                    links.append(
                        SourceGit.GraphLink(
                            start: position,
                            control: CGPoint(x: parent.lastX, y: position.y),
                            end: CGPoint(x: parent.lastX, y: offsetY + halfHeight),
                            colorIndex: parent.colorIndex,
                            isHighlighted: isHighlighted
                        )
                    )
                } else {
                    offsetX += unitWidth
                    let target = CGPoint(x: offsetX, y: position.y + halfHeight)
                    let path = PathHelper(
                        next: parentHash,
                        isHighlighted: isHighlighted,
                        colorIndex: colorPicker.next(),
                        start: target
                    )
                    unsolved.append(path)
                    mutablePaths.append(path.path)
                    pathByNext[parentHash] = path
                    maxLane = max(maxLane, lane(forX: target.x))

                    links.append(
                        SourceGit.GraphLink(
                            start: position,
                            control: CGPoint(x: target.x, y: position.y),
                            end: target,
                            colorIndex: path.colorIndex,
                            isHighlighted: isHighlighted
                        )
                    )
                }
            }

            metadata[commit.hash] = SourceGit.GraphCommitMetadata(
                colorIndex: dotColor,
                isHighlighted: isHighlighted,
                leftMargin: max(offsetX, maxOffsetOld) + halfWidth + 2
            )
        }

        let endY = (Double(commits.count) - halfHeight) * unitHeight
        for (index, path) in unsolved.enumerated() {
            if path.pointCount == 1,
               let firstPoint = path.firstPoint,
               abs(firstPoint.y - endY) < 0.0001 {
                continue
            }

            let endX = (Double(index) + halfHeight) * unitWidth + 4
            path.end(atX: endX, y: endY + halfHeight, halfHeight: halfHeight)
            maxLane = max(maxLane, lane(forX: endX))
        }

        let paths = mutablePaths.map {
            SourceGit.GraphPath(
                points: $0.points,
                colorIndex: $0.colorIndex,
                isHighlighted: $0.isHighlighted
            )
        }

        return SourceGit.CommitGraphModel(
            paths: paths,
            links: links,
            dots: dots,
            laneCount: max(1, maxLane + 1),
            commitMetadata: metadata
        )
    }

    private static func reachableCommits(
        from headHash: String?,
        commits: [Commit],
        rowByHash: [String: Int]
    ) -> Set<String> {
        guard let headHash, rowByHash[headHash] != nil else { return [] }

        var reachable: Set<String> = []
        var pending = [headHash]

        while let hash = pending.popLast() {
            guard reachable.insert(hash).inserted,
                  let row = rowByHash[hash] else {
                continue
            }
            pending.append(contentsOf: commits[row].parents)
        }

        return reachable
    }

    private static func lane(forX x: Double) -> Int {
        max(0, Int(((x - firstLaneX) / unitWidth).rounded()))
    }
}

private final class MutableGraphPath {
    var points: [CGPoint]
    let colorIndex: Int
    let isHighlighted: Bool

    init(points: [CGPoint], colorIndex: Int, isHighlighted: Bool) {
        self.points = points
        self.colorIndex = colorIndex
        self.isHighlighted = isHighlighted
    }
}

private final class PathHelper {
    private(set) var path: MutableGraphPath
    var next: String
    private(set) var lastX: Double
    private var lastY: Double
    private var endY = 0.0

    var colorIndex: Int { path.colorIndex }
    var isHighlighted: Bool { path.isHighlighted }
    var pointCount: Int { path.points.count }
    var firstPoint: CGPoint? { path.points.first }

    init(
        next: String,
        isHighlighted: Bool,
        colorIndex: Int,
        start: CGPoint
    ) {
        self.next = next
        self.lastX = start.x
        self.lastY = start.y
        self.path = MutableGraphPath(
            points: [start],
            colorIndex: colorIndex,
            isHighlighted: isHighlighted
        )
    }

    func pass(x: Double, y: Double, halfHeight: Double) {
        if x > lastX {
            add(x: lastX, y: lastY)
            add(x: x, y: y - halfHeight)
        } else if x < lastX {
            add(x: lastX, y: y - halfHeight)
            let adjustedY = y + halfHeight
            add(x: x, y: adjustedY)
        }
        lastX = x
        lastY = y
    }

    func go(toX x: Double, y: Double, halfHeight: Double) {
        if x > lastX {
            add(x: lastX, y: lastY)
            add(x: x, y: y - halfHeight)
        } else if x < lastX {
            var minimumY = y - halfHeight
            if minimumY > lastY {
                minimumY -= halfHeight
            }
            add(x: lastX, y: minimumY)
            add(x: x, y: y)
        }
        lastX = x
        lastY = y
    }

    func end(atX x: Double, y: Double, halfHeight: Double) {
        if x > lastX {
            add(x: lastX, y: lastY)
            add(x: x, y: y - halfHeight)
        } else if x < lastX {
            add(x: lastX, y: y - halfHeight)
        }
        add(x: x, y: y)
        lastX = x
        lastY = y
    }

    @discardableResult
    func highlight() -> MutableGraphPath {
        let colorIndex = path.colorIndex
        add(x: lastX, y: lastY)
        path = MutableGraphPath(
            points: [CGPoint(x: lastX, y: lastY)],
            colorIndex: colorIndex,
            isHighlighted: true
        )
        endY = 0
        return path
    }

    private func add(x: Double, y: Double) {
        guard endY < y else { return }
        path.points.append(CGPoint(x: x, y: y))
        endY = y
    }
}

private struct ColorPicker {
    private let colorCount: Int
    private var queue: [Int] = []

    init(colorCount: Int) {
        self.colorCount = max(1, colorCount)
    }

    mutating func next() -> Int {
        if queue.isEmpty {
            queue = Array(0..<colorCount)
        }
        return queue.removeFirst()
    }

    mutating func recycle(_ index: Int) {
        guard !queue.contains(index) else { return }
        queue.append(index)
    }
}

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
