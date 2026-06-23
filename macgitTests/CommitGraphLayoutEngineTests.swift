//
//  CommitGraphLayoutEngineTests.swift
//  macgit
//
//  Add this file to the project's Unit Test target to run the layout tests.
//

import XCTest
@testable import macgit

final class CommitGraphLayoutEngineTests: XCTestCase {

    // MARK: - Helpers

    private func makeCommit(
        hash: String,
        parents: [String] = [],
        refs: [String] = []
    ) -> Commit {
        Commit(
            hash: hash,
            parents: parents,
            message: "",
            author: "",
            email: "",
            date: Date(),
            refs: refs
        )
    }

    private func laneMap(_ nodes: [GraphNode]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: nodes.map { ($0.commit.hash, $0.lane) })
    }

    private func assertLayoutConsistency(
        layout: CommitGraphLayout,
        for inputCommits: [Commit],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            layout.nodes.count,
            inputCommits.count,
            "Node count must match input commit count",
            file: file,
            line: line
        )
        for (index, node) in layout.nodes.enumerated() {
            XCTAssertEqual(
                node.rowIndex,
                index,
                "Node row index must preserve input order",
                file: file,
                line: line
            )
            XCTAssertEqual(
                node.commit.hash,
                inputCommits[index].hash,
                "Node commit hash must preserve input order",
                file: file,
                line: line
            )
        }
        let expectedLaneCount = (layout.nodes.map(\.lane).max() ?? 0) + 1
        XCTAssertEqual(
            layout.laneCount,
            expectedLaneCount,
            "laneCount must be consistent with assigned lanes",
            file: file,
            line: line
        )
    }

    // MARK: - Tests

    func testLinearHistory() {
        // A <- B <- C (newest … oldest)
        let c = makeCommit(hash: "c", parents: ["b"])
        let b = makeCommit(hash: "b", parents: ["a"])
        let a = makeCommit(hash: "a", parents: [], refs: ["main"])
        let commits = [c, b, a]
        let layout = CommitGraphLayoutEngine.layout(commits: commits)
        let nodes = layout.nodes

        assertLayoutConsistency(layout: layout, for: commits)
        XCTAssertEqual(nodes[0].lane, 0)
        XCTAssertEqual(nodes[1].lane, 0)
        XCTAssertEqual(nodes[2].lane, 0)
    }

    func testFeatureBranchAndMerge() {
        //     M  (merge f into c — c is first parent)
        //    / \
        //   F   C  (feature tip, main tip)
        //   |   |
        //   .   B
        //   |   |
        //   .   A
        //
        // Newest → oldest: M, F, C, B, A
        // C is on main. F branches from B.

        let a = makeCommit(hash: "a")
        let b = makeCommit(hash: "b", parents: ["a"])
        let c = makeCommit(hash: "c", parents: ["b"], refs: ["main"])
        let f = makeCommit(hash: "f", parents: ["b"])
        let m = makeCommit(hash: "m", parents: ["c", "f"])

        let commits = [m, f, c, b, a]
        let layout = CommitGraphLayoutEngine.layout(commits: commits)
        let nodes = layout.nodes
        let lanes = laneMap(nodes)

        assertLayoutConsistency(layout: layout, for: commits)

        // Main line stays in lane 0
        XCTAssertEqual(lanes["c"], 0)
        XCTAssertEqual(lanes["b"], 0)
        XCTAssertEqual(lanes["a"], 0)

        // Merge commit stays on first-parent lane (main)
        XCTAssertEqual(lanes["m"], 0)

        // Feature branch occupies lane 1
        XCTAssertEqual(lanes["f"], 1)

        // The main path is a straight continuation, merge path is a connector
        let mainPaths = layout.paths.filter { !$0.isMergeConnector }
        let mergePaths = layout.paths.filter { $0.isMergeConnector }
        XCTAssertFalse(mainPaths.isEmpty)
        XCTAssertEqual(mergePaths.count, 1)
    }

    func testParallelBranchesConvergeAtRoot() {
        // Two independent branches from root R:
        // A (main) and B (feature).
        // Both merge back at R.
        //
        // Newest → oldest: A, B, R

        let r = makeCommit(hash: "r")
        let b = makeCommit(hash: "b", parents: ["r"])
        let a = makeCommit(hash: "a", parents: ["r"], refs: ["main"])

        let commits = [a, b, r]
        let layout = CommitGraphLayoutEngine.layout(commits: commits)
        let nodes = layout.nodes
        let lanes = laneMap(nodes)

        assertLayoutConsistency(layout: layout, for: commits)

        // Main line (A) stays in lane 0, feature branch (B) occupies lane 1
        XCTAssertEqual(lanes["a"], 0)
        XCTAssertEqual(lanes["b"], 1)

        // Root R is part of the main line and remains in lane 0
        XCTAssertEqual(lanes["r"], 0)
    }

    func testMergeParentReusesAlreadyActiveLane() {
        // Newest → oldest:
        // A -> D
        // B merges C and D, where D is already being tracked by lane 0.
        //
        // The merge parent should reuse the existing lane for D instead of
        // allocating a third lane.
        let d = makeCommit(hash: "d")
        let c = makeCommit(hash: "c")
        let b = makeCommit(hash: "b", parents: ["c", "d"])
        let a = makeCommit(hash: "a", parents: ["d"])

        let commits = [a, b, c, d]
        let layout = CommitGraphLayoutEngine.layout(commits: commits)
        let lanes = laneMap(layout.nodes)

        assertLayoutConsistency(layout: layout, for: commits)
        XCTAssertEqual(layout.laneCount, 2)
        XCTAssertEqual(lanes["a"], 0)
        XCTAssertEqual(lanes["b"], 1)
        XCTAssertEqual(lanes["c"], 1)
        XCTAssertEqual(lanes["d"], 0)
    }

    func testLayoutReturnsNodesForSimpleHistory() {
        let a = makeCommit(hash: "a")
        let b = makeCommit(hash: "b", parents: ["a"])
        let layout = CommitGraphLayoutEngine.layout(commits: [b, a])
        XCTAssertEqual(layout.nodes.count, 2)
        XCTAssertEqual(layout.nodes[0].lane, 0)
        XCTAssertEqual(layout.nodes[1].lane, 0)
    }

    func testFeatureBranchKeepsStableLanes() {
        let a = makeCommit(hash: "a")
        let b = makeCommit(hash: "b", parents: ["a"])
        let c = makeCommit(hash: "c", parents: ["b"], refs: ["main"])
        let f = makeCommit(hash: "f", parents: ["b"])
        let m = makeCommit(hash: "m", parents: ["c", "f"])

        let layout = CommitGraphLayoutEngine.layout(commits: [m, f, c, b, a])
        let lanes = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.commit.hash, $0.lane) })

        XCTAssertEqual(lanes["m"], 0)
        XCTAssertEqual(lanes["c"], 0)
        XCTAssertEqual(lanes["b"], 0)
        XCTAssertEqual(lanes["a"], 0)
        XCTAssertEqual(lanes["f"], 1)
    }

    func testMergeProducesMergeConnectorPath() {
        let a = makeCommit(hash: "a")
        let b = makeCommit(hash: "b", parents: ["a"])
        let c = makeCommit(hash: "c", parents: ["b"])
        let f = makeCommit(hash: "f", parents: ["b"])
        let m = makeCommit(hash: "m", parents: ["c", "f"])

        let layout = CommitGraphLayoutEngine.layout(commits: [m, f, c, b, a])
        let mergePaths = layout.paths.filter { $0.isMergeConnector }
        XCTAssertEqual(mergePaths.count, 1)
        XCTAssertEqual(mergePaths.first?.points.first?.row, 0)
        XCTAssertEqual(mergePaths.first?.points.last?.row, 1)

        let points = mergePaths.first?.points ?? []
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].row, 0)
        XCTAssertEqual(points[0].lane, 0)
        XCTAssertEqual(points[1].row, 1)
        XCTAssertEqual(points[1].lane, 1)
    }

    func testEmptyHistoryReturnsOneLane() {
        let layout = CommitGraphLayoutEngine.layout(commits: [])
        XCTAssertTrue(layout.nodes.isEmpty)
        XCTAssertTrue(layout.paths.isEmpty)
        XCTAssertEqual(layout.laneCount, 1)
    }

    func testSingleCommit() {
        let a = makeCommit(hash: "a", refs: ["main"])
        let layout = CommitGraphLayoutEngine.layout(commits: [a])

        XCTAssertEqual(layout.nodes.count, 1)
        XCTAssertEqual(layout.nodes[0].lane, 0)
        XCTAssertEqual(layout.laneCount, 1)
        XCTAssertTrue(layout.paths.isEmpty)
    }

    func testOctopusMerge() {
        let a = makeCommit(hash: "a")
        let b = makeCommit(hash: "b", parents: ["a"])
        let c = makeCommit(hash: "c", parents: ["a"])
        let d = makeCommit(hash: "d", parents: ["a"])
        let m = makeCommit(hash: "m", parents: ["b", "c", "d"])

        let commits = [m, b, c, d, a]
        let layout = CommitGraphLayoutEngine.layout(commits: commits)
        let lanes = laneMap(layout.nodes)

        assertLayoutConsistency(layout: layout, for: commits)
        XCTAssertEqual(lanes["m"], 0)
        XCTAssertEqual(lanes["b"], 0)
        XCTAssertEqual(lanes["c"], 1)
        XCTAssertEqual(lanes["d"], 2)
        XCTAssertEqual(lanes["a"], 0)
        XCTAssertEqual(layout.laneCount, 3)

        let mergePaths = layout.paths.filter { $0.isMergeConnector }
        XCTAssertEqual(mergePaths.count, 2)
    }

    func testMissingParentDrawsContinuationPath() {
        let a = makeCommit(hash: "a", parents: ["missing"])
        let layout = CommitGraphLayoutEngine.layout(commits: [a])

        XCTAssertEqual(layout.nodes.count, 1)
        XCTAssertEqual(layout.nodes[0].lane, 0)

        let mainPaths = layout.paths.filter { !$0.isMergeConnector }
        XCTAssertEqual(mainPaths.count, 1)
        let pathPoints = mainPaths.first?.points ?? []
        XCTAssertEqual(pathPoints.count, 2)
        XCTAssertEqual(pathPoints[0].row, 0)
        XCTAssertEqual(pathPoints[0].lane, 0)
        XCTAssertEqual(pathPoints[1].row, 1)
        XCTAssertEqual(pathPoints[1].lane, 0)
    }

    func testComplexDAGMatchesExpectedLanes() {
        // Complex DAG shape (newest → oldest):
        //
        //   c0   c1   c2
        //        |    |
        //        c3   c4
        //       / \   /
        //      c5   c6
        //       \   /
        //        c7
        //
        // c0 is an independent root commit.
        // c1 and c2 share ancestry through c7.
        // c3 is a merge of c5 and c7.
        let c0 = makeCommit(hash: "c0")
        let c1 = makeCommit(hash: "c1", parents: ["c3"])
        let c2 = makeCommit(hash: "c2", parents: ["c4"])
        let c3 = makeCommit(hash: "c3", parents: ["c5", "c7"])
        let c4 = makeCommit(hash: "c4", parents: ["c6"])
        let c5 = makeCommit(hash: "c5", parents: ["c7"])
        let c6 = makeCommit(hash: "c6", parents: ["c7"])
        let c7 = makeCommit(hash: "c7")

        let commits = [c0, c1, c2, c3, c4, c5, c6, c7]
        let layout = CommitGraphLayoutEngine.layout(commits: commits)
        let lanes = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.commit.hash, $0.lane) })

        assertLayoutConsistency(layout: layout, for: commits)

        XCTAssertEqual(lanes["c0"], 0)
        XCTAssertEqual(lanes["c1"], 1)
        XCTAssertEqual(lanes["c2"], 2)
        XCTAssertEqual(lanes["c3"], 1)
        XCTAssertEqual(lanes["c4"], 2)
        XCTAssertEqual(lanes["c5"], 1)
        XCTAssertEqual(lanes["c6"], 2)
        XCTAssertEqual(lanes["c7"], 1)
    }

    func testLayoutPerformanceForLargeDAG() {
        var commits: [Commit] = []
        let count = 1000
        for i in 0..<count {
            let parents: [String]
            if i == count - 1 {
                parents = []
            } else if i % 7 == 0 && i + 2 < count {
                parents = ["\(i + 1)", "\(i + 2)"]
            } else {
                parents = ["\(i + 1)"]
            }
            commits.append(makeCommit(hash: "\(i)", parents: parents))
        }

        var layout: CommitGraphLayout?
        measure {
            layout = CommitGraphLayoutEngine.layout(commits: commits)
        }

        XCTAssertEqual(layout?.nodes.count, count)
        XCTAssertGreaterThan(layout?.paths.count ?? 0, 0)
        XCTAssertLessThanOrEqual(layout?.laneCount ?? 0, count)
    }
}
