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

final class ConflictNavigationStateTests: XCTestCase {
    func testNavigationTargetsOnlyUnresolvedConflicts() {
        let document = ConflictResolutionDocument(
            sections: [
                .context("prefix\n"),
                .conflict(current: "current 1\n", incoming: "incoming 1\n"),
                .context("middle\n"),
                resolvedConflict(current: "current 2\n", incoming: "incoming 2\n"),
                .context("middle 2\n"),
                .conflict(current: "current 3\n", incoming: "incoming 3\n"),
            ],
            currentContent: "",
            incomingContent: ""
        )

        let navigation = ConflictNavigationState(document: document, currentSectionIndex: nil)

        XCTAssertEqual(navigation.unresolvedConflictSectionIndices, [1, 5])
        XCTAssertEqual(navigation.currentSectionIndex, 1)
        // Cyclic navigation wraps around to the last unresolved conflict.
        XCTAssertEqual(navigation.previousSectionIndex, 5)
        XCTAssertEqual(navigation.nextSectionIndex, 5)
        XCTAssertTrue(navigation.canNavigatePrevious)
        XCTAssertTrue(navigation.canNavigateNext)
    }

    func testNavigationSkipsResolvedCurrentConflict() {
        let document = ConflictResolutionDocument(
            sections: [
                .context("prefix\n"),
                .conflict(current: "current 1\n", incoming: "incoming 1\n"),
                resolvedConflict(current: "current 2\n", incoming: "incoming 2\n"),
                .conflict(current: "current 3\n", incoming: "incoming 3\n"),
            ],
            currentContent: "",
            incomingContent: ""
        )

        let navigation = ConflictNavigationState(document: document, currentSectionIndex: 2)

        XCTAssertEqual(navigation.currentSectionIndex, 3)
        // Cyclic navigation wraps around; 1 is both the previous and next target.
        XCTAssertEqual(navigation.previousSectionIndex, 1)
        XCTAssertEqual(navigation.nextSectionIndex, 1)
        XCTAssertTrue(navigation.canNavigatePrevious)
        XCTAssertTrue(navigation.canNavigateNext)
    }

    func testNavigationCyclesSingleConflict() {
        let document = ConflictResolutionDocument(
            sections: [
                .context("prefix\n"),
                .conflict(current: "current 1\n", incoming: "incoming 1\n"),
                .context("suffix\n"),
            ],
            currentContent: "",
            incomingContent: ""
        )

        let navigation = ConflictNavigationState(document: document, currentSectionIndex: nil)

        XCTAssertEqual(navigation.unresolvedConflictSectionIndices, [1])
        XCTAssertEqual(navigation.currentSectionIndex, 1)
        XCTAssertEqual(navigation.previousSectionIndex, 1)
        XCTAssertEqual(navigation.nextSectionIndex, 1)
        XCTAssertTrue(navigation.canNavigatePrevious)
        XCTAssertTrue(navigation.canNavigateNext)
    }

    func testNavigationHasNoTargetsWhenAllConflictsAreResolved() {
        let document = ConflictResolutionDocument(
            sections: [
                resolvedConflict(current: "current 1\n", incoming: "incoming 1\n"),
                .context("middle\n"),
                resolvedConflict(current: "current 2\n", incoming: "incoming 2\n"),
            ],
            currentContent: "",
            incomingContent: ""
        )

        let navigation = ConflictNavigationState(document: document, currentSectionIndex: nil)

        XCTAssertTrue(navigation.unresolvedConflictSectionIndices.isEmpty)
        XCTAssertNil(navigation.currentSectionIndex)
        XCTAssertNil(navigation.previousSectionIndex)
        XCTAssertNil(navigation.nextSectionIndex)
        XCTAssertFalse(navigation.canNavigatePrevious)
        XCTAssertFalse(navigation.canNavigateNext)
    }

    private func resolvedConflict(current: String, incoming: String) -> ConflictResolutionSection {
        var section = ConflictResolutionSection.conflict(current: current, incoming: incoming)
        section.resolution = .incoming
        return section
    }
}
