//
//  CommitGraphGeneratorTests.swift
//  macgitTests
//

import XCTest
@testable import macgit

@MainActor
final class CommitGraphGeneratorTests: XCTestCase {
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

    func testLinearHistory() {
        let a = makeCommit(hash: "a")
        let b = makeCommit(hash: "b", parents: ["a"])
        let c = makeCommit(hash: "c", parents: ["b"])

        let model = CommitGraphGenerator.generate(
            commits: [c, b, a],
            highlighting: .all,
            headHash: "c"
        )

        XCTAssertEqual(model.dots.count, 3)
        XCTAssertEqual(model.paths.count, 1)
        XCTAssertEqual(model.links.count, 0)
        XCTAssertEqual(model.laneCount, 1)
        XCTAssertTrue(model.dots.allSatisfy(\.isHighlighted))
    }

    func testFeatureBranchAndMerge() {
        let a = makeCommit(hash: "a")
        let b = makeCommit(hash: "b", parents: ["a"])
        let c = makeCommit(hash: "c", parents: ["b"], refs: ["main"])
        let f = makeCommit(hash: "f", parents: ["b"])
        let m = makeCommit(hash: "m", parents: ["c", "f"])

        let model = CommitGraphGenerator.generate(
            commits: [m, f, c, b, a],
            highlighting: .all,
            headHash: "m"
        )

        XCTAssertEqual(model.dots.count, 5)
        XCTAssertEqual(model.links.count, 1)
        XCTAssertGreaterThanOrEqual(model.laneCount, 2)
    }

    func testOctopusMerge() {
        let a = makeCommit(hash: "a")
        let b = makeCommit(hash: "b", parents: ["a"])
        let c = makeCommit(hash: "c", parents: ["a"])
        let d = makeCommit(hash: "d", parents: ["a"])
        let m = makeCommit(hash: "m", parents: ["b", "c", "d"])

        let model = CommitGraphGenerator.generate(
            commits: [m, b, c, d, a],
            highlighting: .all,
            headHash: "m"
        )

        XCTAssertEqual(model.links.count, 2)
        XCTAssertGreaterThanOrEqual(model.laneCount, 3)
    }

    func testCurrentBranchOnlyHighlighting() {
        let a = makeCommit(hash: "a")
        let b = makeCommit(hash: "b", parents: ["a"])
        let c = makeCommit(hash: "c", parents: ["b"], refs: ["main"])
        let f = makeCommit(hash: "f", parents: ["b"])
        let m = makeCommit(hash: "m", parents: ["c", "f"])

        let model = CommitGraphGenerator.generate(
            commits: [m, f, c, b, a],
            highlighting: .currentBranchOnly,
            headHash: "c"
        )

        let highlightedDots = model.dots.filter(\.isHighlighted)
        XCTAssertEqual(highlightedDots.count, 3)
        XCTAssertEqual(
            model.commitMetadata.filter(\.value.isHighlighted).map(\.key).sorted(),
            ["a", "b", "c"]
        )
    }

    func testMissingParentDrawsContinuationPath() {
        let a = makeCommit(hash: "a", parents: ["missing"])
        let model = CommitGraphGenerator.generate(
            commits: [a],
            highlighting: .all,
            headHash: "a"
        )

        XCTAssertEqual(model.dots.count, 1)
        XCTAssertEqual(model.paths.count, 1)
        let lastPoint = model.paths.first?.points.last
        XCTAssertEqual(lastPoint?.y, 0.5)
    }

    func testRemoteBranchHeadCreatesNewPath() {
        let a = makeCommit(hash: "a")
        let b = makeCommit(hash: "b", parents: ["a"], refs: ["origin/main"])
        let c = makeCommit(hash: "c", parents: ["a"], refs: ["main"])

        let model = CommitGraphGenerator.generate(
            commits: [c, b, a],
            highlighting: .all,
            headHash: "c"
        )

        XCTAssertGreaterThanOrEqual(model.laneCount, 2)
    }

    func testHeadAndMergeDotTypes() {
        let a = makeCommit(hash: "a")
        let b = makeCommit(hash: "b", parents: ["a"])
        let c = makeCommit(hash: "c", parents: ["a"])
        let m = makeCommit(hash: "m", parents: ["b", "c"], refs: ["HEAD -> main"])

        let model = CommitGraphGenerator.generate(
            commits: [m, b, c, a],
            highlighting: .all,
            headHash: "m"
        )

        XCTAssertEqual(model.dots.first?.type, .head)
        XCTAssertEqual(model.dots[1].type, .default)
    }

    func testEmptyHistoryReturnsOneLane() {
        let model = CommitGraphGenerator.generate(
            commits: [],
            highlighting: .all,
            headHash: nil
        )

        XCTAssertTrue(model.paths.isEmpty)
        XCTAssertTrue(model.links.isEmpty)
        XCTAssertTrue(model.dots.isEmpty)
        XCTAssertEqual(model.laneCount, 1)
    }
}
