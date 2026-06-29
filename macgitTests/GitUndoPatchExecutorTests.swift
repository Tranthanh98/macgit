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
import XCTest
@testable import macgit

final class GitUndoPatchExecutorTests: XCTestCase {
    func testApplyPatchOperationUsesPatchRunnerFlags() async throws {
        let runner = RecordingGitRunner()
        let patchRunner = RecordingPatchRunner()
        let executor = GitUndoExecutor(runner: runner, patchRunner: patchRunner)
        let repoURL = URL(fileURLWithPath: "/tmp/repo")

        try await executor.execute(
            .applyPatch(patch: "patch text", cached: true, reverse: true),
            in: repoURL
        )

        let calls = await patchRunner.recordedCalls()
        XCTAssertEqual(calls, [
            PatchCall(patch: "patch text", directory: repoURL, cached: true, reverse: true)
        ])
        let commandCalls = await runner.recordedCalls()
        XCTAssertTrue(commandCalls.isEmpty)
    }
}

private struct GitCommandCall: Equatable {
    let arguments: [String]
    let directory: URL
}

private actor RecordingGitRunner: GitCommandRunning {
    private var calls: [GitCommandCall] = []

    func runGit(arguments: [String], in directory: URL) async throws -> String {
        calls.append(GitCommandCall(arguments: arguments, directory: directory))
        return ""
    }

    func recordedCalls() -> [GitCommandCall] {
        calls
    }
}

private struct PatchCall: Equatable {
    let patch: String
    let directory: URL
    let cached: Bool
    let reverse: Bool
}

private actor RecordingPatchRunner: GitPatchApplying {
    private var calls: [PatchCall] = []

    func applyPatch(_ patch: String, in repositoryURL: URL, cached: Bool, reverse: Bool) async throws {
        calls.append(PatchCall(patch: patch, directory: repositoryURL, cached: cached, reverse: reverse))
    }

    func recordedCalls() -> [PatchCall] {
        calls
    }
}
