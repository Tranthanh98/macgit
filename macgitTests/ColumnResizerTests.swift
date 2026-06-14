import XCTest
@testable import macgit

final class ColumnResizerTests: XCTestCase {
    func testDraggedTwoColumnWidthsAreClampedAndBalancedOnCommit() {
        let result = ColumnResizer.committedWidths(
            initialLeft: 120,
            initialRight: 80,
            translation: 30,
            hasRightColumn: true
        )

        XCTAssertEqual(result.left, 150)
        XCTAssertEqual(result.right, 50)
    }
}
