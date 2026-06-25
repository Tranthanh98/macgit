import XCTest
@testable import macgit

final class SidebarViewStashTests: XCTestCase {
    func testSidebarSectionStateDecodesMissingStashesExpandedAsTrue() throws {
        let data = #"{"branchesExpanded":false,"tagsExpanded":true,"remotesExpanded":false}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SidebarSectionState.self, from: data)

        XCTAssertFalse(decoded.branchesExpanded)
        XCTAssertTrue(decoded.tagsExpanded)
        XCTAssertFalse(decoded.remotesExpanded)
        XCTAssertTrue(decoded.stashesExpanded)
    }

    func testSidebarSettingsStorePersistsStashesSectionToggle() {
        let repositoryPath = "/tmp/sidebar-stash-\(UUID().uuidString)"

        let initialState = SidebarSettingsStore.shared.state(for: repositoryPath)
        XCTAssertTrue(initialState.stashesExpanded)

        SidebarSettingsStore.shared.toggleSection(.stashes, for: repositoryPath)

        let updatedState = SidebarSettingsStore.shared.state(for: repositoryPath)
        XCTAssertFalse(updatedState.stashesExpanded)
        XCTAssertTrue(updatedState.branchesExpanded)
        XCTAssertTrue(updatedState.tagsExpanded)
        XCTAssertTrue(updatedState.remotesExpanded)
    }

    func testSidebarSectionStateDecodesMissingWorktreesExpandedAsTrue() throws {
        let data = #"{"branchesExpanded":true,"tagsExpanded":false}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SidebarSectionState.self, from: data)

        XCTAssertTrue(decoded.worktreesExpanded)
    }
}
