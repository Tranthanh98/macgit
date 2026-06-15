import XCTest
@testable import macgit

final class BranchGraphCanvasTests: XCTestCase {
    func testRoutesMergeParentWithRoundedCornerAtSource() {
        let edge = GraphEdge(fromRow: 0, fromLane: 1, toRow: 3, toLane: 0, isMergeParent: true)

        let route = BranchGraphCanvas.edgeRoute(for: edge, rowHeight: 20, laneWidth: 10)

        XCTAssertEqual(route.start, CGPoint(x: 15, y: 10))
        XCTAssertEqual(route.preTurn, CGPoint(x: 9, y: 10))
        XCTAssertEqual(route.corner, CGPoint(x: 5, y: 10))
        XCTAssertEqual(route.postTurn, CGPoint(x: 5, y: 14))
        XCTAssertEqual(route.end, CGPoint(x: 5, y: 70))
    }

    func testRoutesFirstParentWithRoundedCornerAtDestination() {
        let edge = GraphEdge(fromRow: 0, fromLane: 0, toRow: 3, toLane: 1, isMergeParent: false)

        let route = BranchGraphCanvas.edgeRoute(for: edge, rowHeight: 20, laneWidth: 10)

        XCTAssertEqual(route.start, CGPoint(x: 5, y: 10))
        XCTAssertEqual(route.preTurn, CGPoint(x: 5, y: 66))
        XCTAssertEqual(route.corner, CGPoint(x: 5, y: 70))
        XCTAssertEqual(route.postTurn, CGPoint(x: 9, y: 70))
        XCTAssertEqual(route.end, CGPoint(x: 15, y: 70))
    }
}
