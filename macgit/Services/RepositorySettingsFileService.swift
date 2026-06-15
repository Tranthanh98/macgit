import Foundation

struct RepositorySettingsFileService {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func prepareGitIgnore(in repositoryURL: URL) throws -> URL {
        let gitIgnoreURL = repositoryURL.appendingPathComponent(".gitignore")
        if !fileManager.fileExists(atPath: gitIgnoreURL.path) {
            fileManager.createFile(atPath: gitIgnoreURL.path, contents: Data())
        }
        return gitIgnoreURL
    }

    func gitConfigURL(in repositoryURL: URL) -> URL? {
        let configURL = repositoryURL
            .appendingPathComponent(".git", isDirectory: true)
            .appendingPathComponent("config")
        return fileManager.fileExists(atPath: configURL.path) ? configURL : nil
    }
}
