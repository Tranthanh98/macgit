import XCTest
@testable import macgit

@MainActor
final class FileStatusActionSelectionTests: XCTestCase {
    func testSectionTitlesUseAllWhenNothingIsSelected() {
        let policy = FileStatusActionSelection(
            selectedKeys: [],
            stagedFiles: [file("README.md", status: .staged)],
            changedFiles: [file("Sources/App.swift", status: .modified)]
        )

        XCTAssertEqual(policy.title(for: .staged), "Unstage All")
        XCTAssertEqual(policy.title(for: .changed), "Stage All")
    }

    func testSectionTitlesUseSelectedForSectionsWithSelectedFiles() {
        let staged = file("README.md", status: .staged)
        let changed = file("Sources/App.swift", status: .modified)
        let policy = FileStatusActionSelection(
            selectedKeys: [
                FileStatusSelectionKey(file: staged, isStaged: true),
                FileStatusSelectionKey(file: changed, isStaged: false)
            ],
            stagedFiles: [staged],
            changedFiles: [changed]
        )

        XCTAssertEqual(policy.title(for: .staged), "Unstage selected")
        XCTAssertEqual(policy.title(for: .changed), "Stage selected")
    }

    func testMenuTitlesUseSelectedWhenMultipleFilesAreSelected() {
        let first = file("Sources/App.swift", status: .modified)
        let second = file("Sources/Model.swift", status: .modified)
        let policy = FileStatusActionSelection(
            selectedKeys: [
                FileStatusSelectionKey(file: first, isStaged: false),
                FileStatusSelectionKey(file: second, isStaged: false)
            ],
            stagedFiles: [],
            changedFiles: [first, second]
        )

        XCTAssertTrue(policy.isSingleFileActionDisabled)
        XCTAssertEqual(policy.title(for: .stage), "Stage selected")
        XCTAssertEqual(policy.title(for: .discard), "Discard selected")
        XCTAssertEqual(policy.title(for: .remove), "Remove selected")
    }

    func testActionFilesUseSelectedEligibleFilesWhenMultipleFilesAreSelected() {
        let staged = file("README.md", status: .staged)
        let changed = file("Sources/App.swift", status: .modified)
        let untracked = file("Notes.txt", status: .untracked)
        let policy = FileStatusActionSelection(
            selectedKeys: [
                FileStatusSelectionKey(file: staged, isStaged: true),
                FileStatusSelectionKey(file: changed, isStaged: false),
                FileStatusSelectionKey(file: untracked, isStaged: false)
            ],
            stagedFiles: [staged],
            changedFiles: [changed, untracked]
        )

        XCTAssertEqual(policy.files(for: .stage, fallback: changed), [changed, untracked])
        XCTAssertEqual(policy.files(for: .unstage, fallback: staged), [staged])
        XCTAssertEqual(policy.files(for: .discard, fallback: changed), [changed, untracked])
        XCTAssertEqual(policy.files(for: .remove, fallback: changed), [staged, changed, untracked])
    }

    func testRemoveSelectedDeduplicatesPathsThatAppearInBothSections() {
        let staged = file("Sources/App.swift", status: .staged)
        let changed = file("Sources/App.swift", status: .modified)
        let untracked = file("Notes.txt", status: .untracked)
        let policy = FileStatusActionSelection(
            selectedKeys: [
                FileStatusSelectionKey(file: staged, isStaged: true),
                FileStatusSelectionKey(file: changed, isStaged: false),
                FileStatusSelectionKey(file: untracked, isStaged: false)
            ],
            stagedFiles: [staged],
            changedFiles: [changed, untracked]
        )

        XCTAssertEqual(policy.files(for: .remove, fallback: changed).map(\.path), ["Sources/App.swift", "Notes.txt"])
    }

    func testPrunedSelectionDropsFilesNoLongerPresent() {
        let present = file("README.md", status: .staged)
        let missing = file("Deleted.swift", status: .modified)
        let policy = FileStatusActionSelection(
            selectedKeys: [
                FileStatusSelectionKey(file: present, isStaged: true),
                FileStatusSelectionKey(file: missing, isStaged: false)
            ],
            stagedFiles: [present],
            changedFiles: []
        )

        XCTAssertEqual(policy.prunedSelection, [FileStatusSelectionKey(file: present, isStaged: true)])
    }

    private func file(_ path: String, status: FileStatus) -> StatusFile {
        StatusFile(path: path, status: status, originalPath: nil)
    }
}
