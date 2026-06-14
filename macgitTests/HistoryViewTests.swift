import XCTest
@testable import macgit

final class HistoryViewTests: XCTestCase {
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
}
