import XCTest
@testable import macgit

final class BranchSyncBadgePolicyTests: XCTestCase {
    func testLoadingBadgeShowsWhilePullingTheMatchingBranch() {
        XCTAssertTrue(
            BranchSyncBadgePolicy.shouldShowLoading(
                for: "feature/new-feat",
                isPulling: true,
                isPushing: false,
                activeSyncBranch: "feature/new-feat"
            )
        )
    }

    func testLoadingBadgeHidesForOtherBranches() {
        XCTAssertFalse(
            BranchSyncBadgePolicy.shouldShowLoading(
                for: "feature/new-feat",
                isPulling: true,
                isPushing: false,
                activeSyncBranch: "feature/other"
            )
        )
    }
}
