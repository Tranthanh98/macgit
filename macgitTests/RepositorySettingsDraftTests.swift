import XCTest
@testable import macgit

final class RepositorySettingsDraftTests: XCTestCase {
    func testDraftPrefersSavedBranchWhenItExistsInDetectedBranches() {
        let settings = RepoSettings(
            defaultRemoteName: "origin",
            defaultPullBranch: "release",
            pullStrategy: .merge,
            autoFetchEnabled: false,
            refreshOnAppActive: true,
            confirmDetachedHeadCheckout: true,
            confirmDestructiveStashActions: true
        )

        let draft = RepositorySettingsDraft(
            settings: settings,
            remotes: ["origin", "upstream"],
            branches: ["main", "release"],
            currentBranch: "main"
        )

        XCTAssertEqual(draft.selectedRemoteName, "origin")
        XCTAssertEqual(draft.selectedBranchMode, .detected)
        XCTAssertEqual(draft.selectedDetectedBranch, "release")
        XCTAssertEqual(draft.manualBranchName, "")
    }

    func testDraftFallsBackToManualBranchEntryWhenSavedBranchIsCustom() {
        let draft = RepositorySettingsDraft(
            settings: RepoSettings(
                defaultRemoteName: "origin",
                defaultPullBranch: "release/hotfix",
                pullStrategy: .rebase,
                autoFetchEnabled: true,
                refreshOnAppActive: false,
                confirmDetachedHeadCheckout: false,
                confirmDestructiveStashActions: false
            ),
            remotes: ["origin"],
            branches: ["main", "develop"],
            currentBranch: "main"
        )

        XCTAssertEqual(draft.selectedBranchMode, .manual)
        XCTAssertEqual(draft.manualBranchName, "release/hotfix")
        XCTAssertEqual(draft.resolvedSettings.defaultPullBranch, "release/hotfix")
        XCTAssertEqual(draft.resolvedSettings.pullStrategy, .rebase)
    }

    func testDraftTrimsManualBranchNameOnSave() {
        var draft = RepositorySettingsDraft(
            settings: RepoSettings.defaults(currentBranch: "main", remotes: ["origin"]),
            remotes: ["origin"],
            branches: ["main"],
            currentBranch: "main"
        )
        draft.selectedBranchMode = .manual
        draft.manualBranchName = "  release/v2  "

        XCTAssertEqual(draft.resolvedSettings.defaultPullBranch, "release/v2")
    }
}
