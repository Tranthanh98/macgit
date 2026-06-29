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
import AppKit
@testable import macgit
import XCTest

final class PersistentSplitViewTests: XCTestCase {
    func testLeftRightSplitUsesHorizontalResizeCursor() {
        XCTAssertIdentical(
            ResizableCursorSplitView.dividerCursor(forSplitViewIsVertical: true),
            NSCursor.resizeLeftRight
        )
    }

    func testTopBottomSplitUsesVerticalResizeCursor() {
        XCTAssertIdentical(
            ResizableCursorSplitView.dividerCursor(forSplitViewIsVertical: false),
            NSCursor.resizeUpDown
        )
    }

    func testDividerHitAreaExpandsAroundThinDivider() {
        let dividerRect = ResizableCursorSplitView.dividerCursorRect(
            for: NSRect(x: 200, y: 0, width: 1, height: 100),
            splitViewIsVertical: true
        )

        XCTAssertGreaterThanOrEqual(dividerRect.width, 8)
        XCTAssertTrue(dividerRect.contains(NSPoint(x: 203, y: 50)))
    }

    func testSplitViewConfigurationUsesNativeAutosaveNameForGlobalPersistence() {
        let splitView = ResizableCursorSplitView()

        configurePersistentSplitView(splitView, autosaveName: "FileStatusMainSplit", isVertical: true)

        XCTAssertEqual(splitView.autosaveName, "FileStatusMainSplit")
        XCTAssertTrue(splitView.isVertical)
        XCTAssertEqual(splitView.dividerStyle, .thin)
        XCTAssertNil(splitView.delegate)
    }
}
