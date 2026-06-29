//
//  macgit (Commit+) - a macOS Git client built with Swift and SwiftUI.
//  Copyright (C) 2026  Thanh Tran <trantienthanh2412@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Affero General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Affero General Public License for more details.
//
//  You should have received a copy of the GNU Affero General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
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
