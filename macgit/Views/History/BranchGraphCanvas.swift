//
//  BranchGraphCanvas.swift
//  macgit
//

import SwiftUI

struct BranchGraphCanvas: View {
    let nodes: [GraphNode]
    let edges: [GraphEdge]
    let laneCount: Int

    let rowHeight: CGFloat = 24
    let laneWidth: CGFloat = 14
    let dotSize: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            guard !nodes.isEmpty else { return }

            // 1. Draw edges (lines / curves)
            for edge in edges {
                let route = Self.edgeRoute(for: edge, rowHeight: rowHeight, laneWidth: laneWidth)

                let color: Color
                if edge.fromLane == edge.toLane {
                    color = LaneColors.color(for: edge.fromLane)
                } else if edge.isMergeParent {
                    color = LaneColors.color(for: edge.toLane)
                } else {
                    color = LaneColors.color(for: edge.fromLane)
                }

                var path = Path()
                path.move(to: route.start)
                if edge.fromLane == edge.toLane {
                    path.addLine(to: route.end)
                } else {
                    path.addLine(to: route.preTurn)
                    path.addQuadCurve(to: route.postTurn, control: route.corner)
                    path.addLine(to: route.end)
                }

                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
            }

            // 2. Draw dots on top
            for node in nodes {
                let y = CGFloat(node.rowIndex) * rowHeight + rowHeight / 2
                let x = CGFloat(node.lane) * laneWidth + laneWidth / 2
                let color = LaneColors.color(for: node.lane)

                let dotRect = CGRect(
                    x: x - dotSize / 2,
                    y: y - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )

                let dotPath = Path(ellipseIn: dotRect)
                context.fill(dotPath, with: .color(color))

                // White border for dot
                context.stroke(dotPath, with: .color(.white), lineWidth: 1.5)

                // Draw merge indicator (slightly larger dot for merge commits)
                if node.commit.isMerge {
                    let mergePath = Path(ellipseIn: dotRect.insetBy(dx: -2, dy: -2))
                    context.stroke(mergePath, with: .color(color.opacity(0.5)), lineWidth: 1.5)
                }
            }
        }
        .frame(width: graphWidth, height: CGFloat(nodes.count) * rowHeight)
        .fixedSize()
    }

    private var graphWidth: CGFloat {
        return CGFloat(laneCount) * laneWidth + 8
    }

    struct EdgeRoute {
        let start: CGPoint
        let preTurn: CGPoint
        let corner: CGPoint
        let postTurn: CGPoint
        let end: CGPoint
    }

    static func edgeRoute(for edge: GraphEdge, rowHeight: CGFloat, laneWidth: CGFloat) -> EdgeRoute {
        let y1 = CGFloat(edge.fromRow) * rowHeight + rowHeight / 2
        let x1 = CGFloat(edge.fromLane) * laneWidth + laneWidth / 2
        let y2 = CGFloat(edge.toRow) * rowHeight + rowHeight / 2
        let x2 = CGFloat(edge.toLane) * laneWidth + laneWidth / 2

        let start = CGPoint(x: x1, y: y1)
        let end = CGPoint(x: x2, y: y2)

        guard edge.fromLane != edge.toLane else {
            return EdgeRoute(start: start, preTurn: start, corner: start, postTurn: end, end: end)
        }

        let cornerRadius = min(4, min(abs(x2 - x1) / 2, abs(y2 - y1) / 2))

        if edge.isMergeParent {
            let xDirection = x2 >= x1 ? 1 as CGFloat : -1 as CGFloat
            let yDirection = y2 >= y1 ? 1 as CGFloat : -1 as CGFloat
            let preTurn = CGPoint(x: x2 - xDirection * cornerRadius, y: y1)
            let corner = CGPoint(x: x2, y: y1)
            let postTurn = CGPoint(x: x2, y: y1 + yDirection * cornerRadius)
            return EdgeRoute(start: start, preTurn: preTurn, corner: corner, postTurn: postTurn, end: end)
        } else {
            let xDirection = x2 >= x1 ? 1 as CGFloat : -1 as CGFloat
            let yDirection = y2 >= y1 ? 1 as CGFloat : -1 as CGFloat
            let preTurn = CGPoint(x: x1, y: y2 - yDirection * cornerRadius)
            let corner = CGPoint(x: x1, y: y2)
            let postTurn = CGPoint(x: x1 + xDirection * cornerRadius, y: y2)
            return EdgeRoute(start: start, preTurn: preTurn, corner: corner, postTurn: postTurn, end: end)
        }
    }
}
