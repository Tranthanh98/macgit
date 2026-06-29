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

final class HistoryCommitSelectionTests: XCTestCase {
    func testPlainSelectionReplacesExistingSelection() {
        var selection = HistoryCommitSelection()
        let visible = ["newest", "middle", "oldest"]

        selection.select("newest", modifiers: [], visibleHashes: visible)
        selection.select("middle", modifiers: [], visibleHashes: visible)

        XCTAssertEqual(selection.selectedHashes, ["middle"])
        XCTAssertEqual(selection.primaryHash, "middle")
        XCTAssertEqual(selection.anchorHash, "middle")
    }

    func testCommandSelectionTogglesHashes() {
        var selection = HistoryCommitSelection()
        let visible = ["newest", "middle", "oldest"]

        selection.select("newest", modifiers: [], visibleHashes: visible)
        selection.select("middle", modifiers: [.command], visibleHashes: visible)
        selection.select("newest", modifiers: [.command], visibleHashes: visible)

        XCTAssertEqual(selection.selectedHashes, ["middle"])
        XCTAssertEqual(selection.primaryHash, "middle")
        XCTAssertEqual(selection.anchorHash, "middle")
    }

    func testShiftSelectionUsesInclusiveVisibleRangeFromAnchor() {
        var selection = HistoryCommitSelection()
        let visible = ["newest", "middle", "older", "oldest"]

        selection.select("middle", modifiers: [], visibleHashes: visible)
        selection.select("oldest", modifiers: [.shift], visibleHashes: visible)

        XCTAssertEqual(selection.selectedHashes, ["middle", "older", "oldest"])
        XCTAssertEqual(selection.primaryHash, "oldest")
        XCTAssertEqual(selection.anchorHash, "middle")
    }

    func testPrimaryHashTracksLastSelectedCommit() {
        var selection = HistoryCommitSelection()
        let visible = ["newest", "middle", "oldest"]

        selection.select("newest", modifiers: [], visibleHashes: visible)
        selection.select("oldest", modifiers: [.command], visibleHashes: visible)

        XCTAssertEqual(selection.primaryHash, "oldest")
        XCTAssertEqual(selection.anchorHash, "oldest")
    }

    func testPruneRemovesHashesMissingAfterReload() {
        var selection = HistoryCommitSelection(
            selectedHashes: ["newest", "middle", "oldest"],
            primaryHash: "middle",
            anchorHash: "oldest"
        )

        selection.prune(visibleHashes: ["middle", "oldest"])

        XCTAssertEqual(selection.selectedHashes, ["middle", "oldest"])
        XCTAssertEqual(selection.primaryHash, "middle")
        XCTAssertEqual(selection.anchorHash, "oldest")
    }

    func testPruneClearsPrimaryAndAnchorWhenTheyDisappear() {
        var selection = HistoryCommitSelection(
            selectedHashes: ["newest", "middle"],
            primaryHash: "newest",
            anchorHash: "newest"
        )

        selection.prune(visibleHashes: ["oldest"])

        XCTAssertTrue(selection.selectedHashes.isEmpty)
        XCTAssertNil(selection.primaryHash)
        XCTAssertNil(selection.anchorHash)
    }

    func testDraggedHashesUsesCurrentSelectionWhenStartingOnSelectedRow() {
        var selection = HistoryCommitSelection()
        let visible = ["newest", "middle", "oldest"]

        selection.select("newest", modifiers: [], visibleHashes: visible)
        selection.select("oldest", modifiers: [.command], visibleHashes: visible)

        XCTAssertEqual(
            selection.draggedHashes(startingAt: "newest", visibleHashes: visible),
            ["oldest", "newest"]
        )
    }

    func testDraggedHashesFallsBackToDraggedRowWhenItIsNotSelected() {
        var selection = HistoryCommitSelection()
        let visible = ["newest", "middle", "oldest"]

        selection.select("newest", modifiers: [], visibleHashes: visible)

        XCTAssertEqual(
            selection.draggedHashes(startingAt: "middle", visibleHashes: visible),
            ["middle"]
        )
    }

    func testDraggedHashesDropsNonVisibleHashesAndReturnsOldestFirst() {
        let selection = HistoryCommitSelection(
            selectedHashes: ["newest", "stale", "middle", "oldest"],
            primaryHash: "newest",
            anchorHash: "middle"
        )
        let visible = ["newest", "middle", "oldest"]

        XCTAssertEqual(
            selection.draggedHashes(startingAt: "newest", visibleHashes: visible),
            ["oldest", "middle", "newest"]
        )
    }
}
