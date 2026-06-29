//
//  GitRemoteUndoSupport.swift
//  macgit
//

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

struct GitRemoteUndoSupport {
    private let runner: any GitCommandRunning

    init(runner: (any GitCommandRunning)? = nil) {
        self.runner = runner ?? GitStatusService.shared
    }

    func remoteHash(remote: String, branch: String, in repositoryURL: URL) async throws -> String? {
        let output = try await runner.runGit(arguments: ["ls-remote", remote, "refs/heads/\(branch)"], in: repositoryURL)
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.split(separator: "\t").first.map(String.init)
    }
}
