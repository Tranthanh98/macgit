import XCTest
@testable import macgit

final class RepoSettingsStoreTests: XCTestCase {
    func testRepoSettingsDecodesMissingFieldsWithDefaults() throws {
        let data = #"{"defaultRemoteName":"origin","defaultPullBranch":"main"}"#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(RepoSettings.self, from: data)

        XCTAssertEqual(decoded.defaultRemoteName, "origin")
        XCTAssertEqual(decoded.defaultPullBranch, "main")
        XCTAssertEqual(decoded.pullStrategy, .merge)
        XCTAssertFalse(decoded.autoFetchEnabled)
        XCTAssertTrue(decoded.refreshOnAppActive)
        XCTAssertTrue(decoded.confirmDetachedHeadCheckout)
        XCTAssertTrue(decoded.confirmDestructiveStashActions)
    }

    func testRepoSettingsStorePersistsSettingsPerRepositoryPath() {
        let defaultsKey = "test.repo-settings.\(UUID().uuidString)"
        let store = RepoSettingsStore(userDefaults: UserDefaults.standard, key: defaultsKey)
        let repoA = "/tmp/repo-a-\(UUID().uuidString)"
        let repoB = "/tmp/repo-b-\(UUID().uuidString)"

        var repoASettings = RepoSettings.defaults(currentBranch: "main", remotes: ["origin"])
        repoASettings.pullStrategy = .rebase
        repoASettings.autoFetchEnabled = true
        store.update(for: repoA, settings: repoASettings)

        let loadedA = store.settings(for: repoA, currentBranch: "main", remotes: ["origin"])
        let loadedB = store.settings(for: repoB, currentBranch: "develop", remotes: ["upstream"])

        XCTAssertEqual(loadedA.pullStrategy, .rebase)
        XCTAssertTrue(loadedA.autoFetchEnabled)
        XCTAssertEqual(loadedB.defaultRemoteName, "upstream")
        XCTAssertEqual(loadedB.defaultPullBranch, "develop")
    }
}
