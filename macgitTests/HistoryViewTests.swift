import XCTest
@testable import macgit

@MainActor
final class HistoryViewTests: XCTestCase {
    func testShowAllBranchesMapsToGraphHighlighting() {
        XCTAssertEqual(HistoryView.highlighting(for: true), .all)
        XCTAssertEqual(HistoryView.highlighting(for: false), .currentBranchOnly)
    }

    func testHistoryScopeUsesSelectedBranchWhenShowingSingleBranch() {
        let scope = HistoryView.historyScope(selectedBranch: "feature/login", showAllBranches: false)

        if case .ref(let branch) = scope {
            XCTAssertEqual(branch, "feature/login")
        } else {
            XCTFail("Expected selected branch scope")
        }
    }

    func testHistoryScopeUsesAllBranchesWhenToggleIsEnabled() {
        let scope = HistoryView.historyScope(selectedBranch: "feature/login", showAllBranches: true)

        if case .allBranches = scope {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected all branches scope")
        }
    }

    func testHistoryScopeUsesAllBranchesWhenNoBranchIsSelected() {
        let scope = HistoryView.historyScope(selectedBranch: nil, showAllBranches: false)

        if case .currentBranch = scope {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected current branch scope")
        }
    }

    func testHistoryRowDoesNotAutoCenterWhenVisible() {
        let rowFrames = ["abc123": CGRect(x: 0, y: 0, width: 100, height: 24)]

        XCTAssertFalse(
            HistoryView.shouldAutoCenterCommit(
                targetHash: "abc123",
                rowFrames: rowFrames,
                viewportHeight: 200
            )
        )
    }

    func testHistoryRowDoesNotAutoCenterWhenPartiallyVisible() {
        let rowFrames = ["abc123": CGRect(x: 0, y: 190, width: 100, height: 24)]

        XCTAssertFalse(
            HistoryView.shouldAutoCenterCommit(
                targetHash: "abc123",
                rowFrames: rowFrames,
                viewportHeight: 200
            )
        )
    }

    func testHistoryRowAutoCentersWhenAboveViewport() {
        let rowFrames = ["abc123": CGRect(x: 0, y: -24, width: 100, height: 24)]

        XCTAssertTrue(
            HistoryView.shouldAutoCenterCommit(
                targetHash: "abc123",
                rowFrames: rowFrames,
                viewportHeight: 200
            )
        )
    }

    func testHistoryRowAutoCentersWhenBelowViewport() {
        let rowFrames = ["abc123": CGRect(x: 0, y: 220, width: 100, height: 24)]

        XCTAssertTrue(
            HistoryView.shouldAutoCenterCommit(
                targetHash: "abc123",
                rowFrames: rowFrames,
                viewportHeight: 200
            )
        )
    }

    func testDraggedCommitsUseSelectionForSelectedRowInOldestFirstOrder() {
        let commits = [
            makeCommit(hash: "newest", message: "Newest"),
            makeCommit(hash: "middle", message: "Middle"),
            makeCommit(hash: "oldest", message: "Oldest", parents: ["p1", "p2"])
        ]
        let selection = HistoryCommitSelection(
            selectedHashes: ["newest", "oldest"],
            primaryHash: "newest",
            anchorHash: "oldest"
        )

        XCTAssertEqual(
            HistoryView.draggedCommits(
                startingAt: "newest",
                commits: commits,
                selection: selection
            ),
            [
                GitDraggedCommit(hash: "oldest", message: "Oldest", isMerge: true),
                GitDraggedCommit(hash: "newest", message: "Newest", isMerge: false)
            ]
        )
    }

    func testDraggedCommitsFallBackToDraggedRowWhenRowIsNotSelected() {
        let commits = [
            makeCommit(hash: "newest", message: "Newest"),
            makeCommit(hash: "middle", message: "Middle"),
            makeCommit(hash: "oldest", message: "Oldest")
        ]
        let selection = HistoryCommitSelection(
            selectedHashes: ["newest"],
            primaryHash: "newest",
            anchorHash: "newest"
        )

        XCTAssertEqual(
            HistoryView.draggedCommits(
                startingAt: "middle",
                commits: commits,
                selection: selection
            ),
            [GitDraggedCommit(hash: "middle", message: "Middle", isMerge: false)]
        )
    }

    func testDragPreviewTitleUsesPluralCountForMultiSelection() {
        let commits = [
            makeCommit(hash: "newest", message: "Newest"),
            makeCommit(hash: "oldest", message: "Oldest")
        ]
        let selection = HistoryCommitSelection(
            selectedHashes: ["newest", "oldest"],
            primaryHash: "newest",
            anchorHash: "oldest"
        )

        XCTAssertEqual(
            HistoryView.dragPreviewTitle(
                startingAt: "newest",
                commits: commits,
                selection: selection
            ),
            "2 commits"
        )
    }

    private func makeCommit(
        hash: String,
        message: String,
        parents: [String] = []
    ) -> Commit {
        Commit(
            hash: hash,
            parents: parents,
            message: message,
            author: "Test",
            email: "test@example.com",
            date: Date(timeIntervalSince1970: 0),
            refs: []
        )
    }
}
