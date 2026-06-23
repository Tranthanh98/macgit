import XCTest
@testable import macgit

final class BranchGraphCanvasTests: XCTestCase {
    func testStraightVerticalPathReachesEnd() {
        let path = BranchGraphCanvas.path(
            for: [GraphPoint(row: 0, lane: 0), GraphPoint(row: 2, lane: 0)],
            rowHeight: 20,
            laneWidth: 10
        )
        let rect = path.boundingRect
        XCTAssertEqual(rect.midX, 5, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 10, accuracy: 0.001)
        XCTAssertEqual(rect.maxY, 50, accuracy: 0.001)
    }

    func testLaneChangingPathReachesTarget() {
        let path = BranchGraphCanvas.path(
            for: [GraphPoint(row: 0, lane: 1), GraphPoint(row: 3, lane: 0)],
            rowHeight: 20,
            laneWidth: 10
        )
        let rect = path.boundingRect
        XCTAssertEqual(rect.minX, 5, accuracy: 0.001)
        XCTAssertEqual(rect.maxX, 15, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 10, accuracy: 0.001)
        XCTAssertEqual(rect.maxY, 70, accuracy: 0.001)
    }

    func testSinglePointReturnsEmptyPath() {
        let path = BranchGraphCanvas.path(
            for: [GraphPoint(row: 0, lane: 0)],
            rowHeight: 20,
            laneWidth: 10
        )
        XCTAssertTrue(path.boundingRect.isEmpty)
    }

    func testEmptyPointsArrayReturnsEmptyPath() {
        let path = BranchGraphCanvas.path(for: [], rowHeight: 20, laneWidth: 10)
        XCTAssertTrue(path.boundingRect.isEmpty)
    }

    func testMultiSegmentPathWithStraightAndCurve() {
        let path = BranchGraphCanvas.path(
            for: [
                GraphPoint(row: 0, lane: 0),
                GraphPoint(row: 1, lane: 0),
                GraphPoint(row: 2, lane: 1)
            ],
            rowHeight: 20,
            laneWidth: 10
        )
        let rect = path.boundingRect
        XCTAssertEqual(rect.minX, 5, accuracy: 0.001)
        XCTAssertEqual(rect.maxX, 15, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 10, accuracy: 0.001)
        XCTAssertEqual(rect.maxY, 50, accuracy: 0.001)
    }

    func testMultiLaneJumpReachesTarget() {
        let path = BranchGraphCanvas.path(
            for: [GraphPoint(row: 0, lane: 3), GraphPoint(row: 2, lane: 0)],
            rowHeight: 20,
            laneWidth: 10
        )
        let rect = path.boundingRect
        XCTAssertEqual(rect.minX, 5, accuracy: 0.001)
        XCTAssertEqual(rect.maxX, 35, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 10, accuracy: 0.001)
        XCTAssertEqual(rect.maxY, 50, accuracy: 0.001)
    }
}
