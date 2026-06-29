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

final class GitUndoCommitExecutorTests: XCTestCase {
    func testResetSoftChecksExpectedHeadBeforeResetting() async throws {
        let runner = RecordingGitRunner(outputs: ["rev-parse HEAD": "new-head\n"])
        let executor = GitUndoExecutor(runner: runner)
        let repoURL = URL(fileURLWithPath: "/tmp/repo")

        try await executor.execute(
            .resetHead(target: "old-head", mode: .soft, expectedHead: "new-head"),
            in: repoURL
        )

        let calls = await runner.recordedArguments()
        XCTAssertEqual(calls, [
            ["rev-parse", "HEAD"],
            ["reset", "--soft", "old-head"]
        ])
    }

    func testResetSoftThrowsWhenHeadHasMoved() async throws {
        let runner = RecordingGitRunner(outputs: ["rev-parse HEAD": "someone-else\n"])
        let executor = GitUndoExecutor(runner: runner)

        do {
            try await executor.execute(
                .resetHead(target: "old-head", mode: .soft, expectedHead: "new-head"),
                in: URL(fileURLWithPath: "/tmp/repo")
            )
            XCTFail("Expected expectedHeadMismatch")
        } catch let error as GitUndoError {
            XCTAssertEqual(error, .expectedHeadMismatch(expected: "new-head", actual: "someone-else"))
        }
    }

    func testCommitOperationRunsGitCommitWithOptions() async throws {
        let runner = RecordingGitRunner(outputs: [:])
        let executor = GitUndoExecutor(runner: runner)

        try await executor.execute(
            .commit(message: "ship it", noVerify: true, signOff: true),
            in: URL(fileURLWithPath: "/tmp/repo")
        )

        let calls = await runner.recordedArguments()
        XCTAssertEqual(calls, [
            ["commit", "-m", "ship it", "--no-verify", "--signoff"]
        ])
    }
}

private actor RecordingGitRunner: GitCommandRunning {
    private let outputs: [String: String]
    private var calls: [[String]] = []

    init(outputs: [String: String]) {
        self.outputs = outputs
    }

    func runGit(arguments: [String], in directory: URL) async throws -> String {
        calls.append(arguments)
        return outputs[arguments.joined(separator: " ")] ?? ""
    }

    func recordedArguments() -> [[String]] {
        calls
    }
}
