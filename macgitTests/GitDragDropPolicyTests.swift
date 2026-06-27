import Foundation
import XCTest
@testable import macgit

final class GitDragDropPolicyTests: XCTestCase {
    func testRepositoryMismatchIsRejected() {
        let payload = GitDragPayload.commits(
            [GitDraggedCommit(hash: "c1", message: "commit", isMerge: false)],
            repositoryURL: URL(fileURLWithPath: "/tmp/source-repo")
        )

        XCTAssertEqual(
            GitDragDropPolicy.decision(
                for: payload,
                target: .localBranch(name: "main", isCurrent: true),
                receivingRepositoryURL: URL(fileURLWithPath: "/tmp/other-repo"),
                optionKeyPressed: false
            ),
            .reject("This drag item came from a different repository.")
        )
    }

    func testCommitsCanDropOnCurrentBranchInSameRepository() {
        let repoURL = URL(fileURLWithPath: "/tmp/repo")
        let payload = GitDragPayload.commits(
            [GitDraggedCommit(hash: "c2", message: "second", isMerge: false)],
            repositoryURL: repoURL
        )

        XCTAssertEqual(
            GitDragDropPolicy.decision(
                for: payload,
                target: .localBranch(name: "main", isCurrent: true),
                receivingRepositoryURL: repoURL,
                optionKeyPressed: false
            ),
            .accept(.cherryPick(commits: payload.commits, targetBranch: "main"))
        )
    }

    func testCommitsAreRejectedOnNonCurrentBranch() {
        XCTAssertEqual(
            decision(
                commits: [GitDraggedCommit(hash: "c1", message: "commit", isMerge: false)],
                target: .localBranch(name: "feature", isCurrent: false)
            ),
            .reject("Drop commits only on the current branch.")
        )
    }

    func testMergeCommitIsRejectedForCherryPick() {
        XCTAssertEqual(
            decision(
                commits: [GitDraggedCommit(hash: "merge", message: "merge", isMerge: true)]
            ),
            .reject("Merge commits are not supported by drag and drop yet.")
        )
    }

    func testSingleCommitCanCreateBranchFromBranchesHeader() {
        let commit = GitDraggedCommit(hash: "c3", message: "third", isMerge: false)

        XCTAssertEqual(
            decision(commits: [commit], target: .branchesHeader),
            .accept(.createBranch(startPoint: .commit(hash: "c3", message: "third")))
        )
    }

    func testMergeCommitCanCreateBranchFromBranchesHeader() {
        let commit = GitDraggedCommit(hash: "merge", message: "merge commit", isMerge: true)

        XCTAssertEqual(
            decision(commits: [commit], target: .branchesHeader),
            .accept(.createBranch(startPoint: .commit(hash: "merge", message: "merge commit")))
        )
    }

    func testMultipleCommitsAreRejectedForBranchCreation() {
        XCTAssertEqual(
            decision(
                commits: [
                    GitDraggedCommit(hash: "c1", message: "one", isMerge: false),
                    GitDraggedCommit(hash: "c2", message: "two", isMerge: false),
                ],
                target: .branchesHeader
            ),
            .reject("Select one commit to create a branch.")
        )
    }

    func testEmptyCommitBatchIsRejected() {
        XCTAssertEqual(
            decision(commits: []),
            .reject("Select at least one commit to drag.")
        )
    }

    func testUnsupportedCommitTargetCombinationIsRejected() {
        XCTAssertEqual(
            decision(
                commits: [GitDraggedCommit(hash: "c1", message: "one", isMerge: false)],
                target: .stashesHeader
            ),
            .reject("That drag and drop action is not available yet.")
        )
    }

    private func decision(
        commits: [GitDraggedCommit],
        target: GitDragTarget = .localBranch(name: "main", isCurrent: true),
        repositoryURL: URL = URL(fileURLWithPath: "/tmp/repo")
    ) -> GitDragDropDecision {
        GitDragDropPolicy.decision(
            for: .commits(commits, repositoryURL: repositoryURL),
            target: target,
            receivingRepositoryURL: repositoryURL,
            optionKeyPressed: false
        )
    }
}
