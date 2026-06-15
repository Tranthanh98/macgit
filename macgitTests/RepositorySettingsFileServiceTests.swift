import XCTest
@testable import macgit

final class RepositorySettingsFileServiceTests: XCTestCase {
    func testPrepareGitIgnoreCreatesFileWhenMissing() throws {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("repo-settings-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)

        let service = RepositorySettingsFileService(fileManager: .default)
        let gitIgnoreURL = try service.prepareGitIgnore(in: repoURL)

        XCTAssertEqual(gitIgnoreURL.lastPathComponent, ".gitignore")
        XCTAssertTrue(FileManager.default.fileExists(atPath: gitIgnoreURL.path))
    }

    func testGitConfigReturnsNilWhenConfigDoesNotExist() throws {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("repo-settings-config-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: repoURL.appendingPathComponent(".git", isDirectory: true),
            withIntermediateDirectories: true
        )

        let service = RepositorySettingsFileService(fileManager: .default)

        XCTAssertNil(service.gitConfigURL(in: repoURL))
    }
}
