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

final class DiffPatchBuilderTests: XCTestCase {
    func testWholeHunkPatchIncludesFileHeadersAndHunkLines() {
        let hunk = DiffHunk(
            header: "@@ -1,2 +1,2 @@",
            lines: [
                DiffLine(oldLineNumber: 1, newLineNumber: 1, text: "old", type: .removed),
                DiffLine(oldLineNumber: nil, newLineNumber: 1, text: "new", type: .added),
                DiffLine(oldLineNumber: 2, newLineNumber: 2, text: "same", type: .context)
            ]
        )

        let patch = DiffPatchBuilder.patchString(for: hunk, filePath: "Sources/App.swift")

        XCTAssertEqual(patch, """
        --- a/Sources/App.swift
        +++ b/Sources/App.swift
        @@ -1,2 +1,2 @@
        -old
        +new
         same

        """)
    }

    func testSelectedLinePatchRecomputesHeaderCounts() {
        let removed = DiffLine(oldLineNumber: 1, newLineNumber: nil, text: "remove me", type: .removed)
        let added = DiffLine(oldLineNumber: nil, newLineNumber: 1, text: "add me", type: .added)
        let ignored = DiffLine(oldLineNumber: 2, newLineNumber: 2, text: "ignore me", type: .added)
        let hunk = DiffHunk(
            header: "@@ -1,3 +1,3 @@",
            lines: [
                removed,
                DiffLine(oldLineNumber: 2, newLineNumber: 2, text: "context", type: .context),
                added,
                ignored
            ]
        )

        let patch = DiffPatchBuilder.patchString(
            for: hunk,
            selectedLines: [removed, added],
            filePath: "README.md"
        )

        XCTAssertEqual(patch, """
        --- a/README.md
        +++ b/README.md
        @@ -1,2 +1,2 @@
        -remove me
         context
        +add me

        """)
    }
}
