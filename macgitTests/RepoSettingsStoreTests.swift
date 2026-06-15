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
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: defaultsKey)
        defer { defaults.removeObject(forKey: defaultsKey) }

        let store = RepoSettingsStore(userDefaults: defaults, key: defaultsKey)
        let repoA = "/tmp/repo-a-\(UUID().uuidString)"
        let repoB = "/tmp/repo-b-\(UUID().uuidString)"

        var repoASettings = RepoSettings.defaults(currentBranch: "main", remotes: ["origin"])
        repoASettings.pullStrategy = .rebase
        repoASettings.autoFetchEnabled = true
        store.update(for: repoA, settings: repoASettings)

        let freshStore = RepoSettingsStore(userDefaults: defaults, key: defaultsKey)
        let loadedA = freshStore.settings(for: repoA, currentBranch: "main", remotes: ["origin"])
        let loadedB = freshStore.settings(for: repoB, currentBranch: nil, remotes: ["upstream"])

        XCTAssertEqual(loadedA, repoASettings)
        XCTAssertEqual(loadedB.defaultRemoteName, "upstream")
        XCTAssertEqual(loadedB.defaultPullBranch, "")
        XCTAssertEqual(loadedB.pullStrategy, .merge)
        XCTAssertFalse(loadedB.autoFetchEnabled)
        XCTAssertTrue(loadedB.refreshOnAppActive)
        XCTAssertTrue(loadedB.confirmDetachedHeadCheckout)
        XCTAssertTrue(loadedB.confirmDestructiveStashActions)
    }
}
