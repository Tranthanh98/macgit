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

    // MARK: - Tests

    func testLinearHistory() {
        // A <- B <- C (newest … oldest)
        let c = makeCommit(hash: "c", parents: ["b"])
        let b = makeCommit(hash: "b", parents: ["a"])
        let a = makeCommit(hash: "a", parents: [], refs: ["main"])
        let layout = CommitGraphLayoutEngine.layout(commits: [c, b, a])
        let nodes = layout.nodes

        XCTAssertEqual(nodes[0].lane, 0)
        XCTAssertEqual(nodes[1].lane, 0)
        XCTAssertEqual(nodes[2].lane, 0)

        // Two straight vertical edges
        XCTAssertEqual(layout.edges.count, 2)
        XCTAssertTrue(layout.edges.contains { $0.fromRow == 0 && $0.toRow == 1 && $0.fromLane == 0 && $0.toLane == 0 })
        XCTAssertTrue(layout.edges.contains { $0.fromRow == 1 && $0.toRow == 2 && $0.fromLane == 0 && $0.toLane == 0 })
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

        let layout = CommitGraphLayoutEngine.layout(commits: [m, f, c, b, a])
        let nodes = layout.nodes
        let lanes = laneMap(nodes)

        // Main line stays in lane 0
        XCTAssertEqual(lanes["c"], 0)
        XCTAssertEqual(lanes["b"], 0)
        XCTAssertEqual(lanes["a"], 0)

        // Merge commit stays on first-parent lane (main)
        XCTAssertEqual(lanes["m"], 0)

        // Feature branch occupies lane 1
        XCTAssertEqual(lanes["f"], 1)

        // Verify edges
        // M -> C (first parent, straight down)
        XCTAssertTrue(layout.edges.contains {
            $0.fromRow == 0 && $0.toRow == 2 && $0.fromLane == 0 && $0.toLane == 0 && !$0.isMergeParent
        })
        // M -> F (merge parent, cross lane)
        XCTAssertTrue(layout.edges.contains {
            $0.fromRow == 0 && $0.toRow == 1 && $0.fromLane == 0 && $0.toLane == 1 && $0.isMergeParent
        })
        // F -> B (feature continues)
        XCTAssertTrue(layout.edges.contains {
            $0.fromRow == 1 && $0.toRow == 3 && $0.fromLane == 1 && $0.toLane == 0 && !$0.isMergeParent
        })
        // C -> B (main continues)
        XCTAssertTrue(layout.edges.contains {
            $0.fromRow == 2 && $0.toRow == 3 && $0.fromLane == 0 && $0.toLane == 0 && !$0.isMergeParent
        })
        // B -> A (main continues)
        XCTAssertTrue(layout.edges.contains {
            $0.fromRow == 3 && $0.toRow == 4 && $0.fromLane == 0 && $0.toLane == 0 && !$0.isMergeParent
        })
    }

    func testParallelBranchesReuseLane() {
        // Two independent branches from root R:
        // A (main) and B (feature).
        // Both merge back at R.
        //
        // Newest → oldest: A, B, R

        let r = makeCommit(hash: "r")
        let b = makeCommit(hash: "b", parents: ["r"])
        let a = makeCommit(hash: "a", parents: ["r"], refs: ["main"])

        let layout = CommitGraphLayoutEngine.layout(commits: [a, b, r])
        let nodes = layout.nodes
        let lanes = laneMap(nodes)

        // Trunk (A) gets lane 0, feature (B) gets lane 1
        XCTAssertEqual(lanes["a"], 0)
        XCTAssertEqual(lanes["b"], 1)

        // Both lanes converge at root R, which reuses lane 0
        // and frees lane 1 for future reuse
        XCTAssertEqual(lanes["r"], 0)

        // Verify edges
        XCTAssertTrue(layout.edges.contains {
            $0.fromRow == 0 && $0.toRow == 2 && $0.fromLane == 0 && $0.toLane == 0 && !$0.isMergeParent
        })
        XCTAssertTrue(layout.edges.contains {
            $0.fromRow == 1 && $0.toRow == 2 && $0.fromLane == 1 && $0.toLane == 0 && !$0.isMergeParent
        })
    }
}
