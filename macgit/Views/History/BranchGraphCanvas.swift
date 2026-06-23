//
//  BranchGraphCanvas.swift
//  macgit
//

import SwiftUI

struct BranchGraphCanvas: View {
    let nodes: [GraphNode]
    let paths: [GraphPath]
    let laneCount: Int

    let rowHeight: CGFloat = 24
    let laneWidth: CGFloat = 14
    let dotSize: CGFloat = 8
    let graphTrailingPadding: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            guard !nodes.isEmpty else { return }

            // 1. Draw paths (polylines with rounded lane-change corners)
            for pathModel in paths {
                guard pathModel.points.count > 1 else { continue }
                let path = Self.path(
                    for: pathModel.points,
                    rowHeight: rowHeight,
                    laneWidth: laneWidth
                )

                context.stroke(
                    path,
                    with: .color(pathModel.color),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
            }

            // 2. Draw dots on top
            for node in nodes {
                let color = LaneColors.color(for: node.lane)
                let position = pointPosition(GraphPoint(row: node.rowIndex, lane: node.lane))

                let dotRect = CGRect(
                    x: position.x - dotSize / 2,
                    y: position.y - dotSize / 2,
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
        return CGFloat(laneCount) * laneWidth + graphTrailingPadding
    }

    private func pointPosition(_ point: GraphPoint) -> CGPoint {
        CGPoint(
            x: CGFloat(point.lane) * laneWidth + laneWidth / 2,
            y: CGFloat(point.row) * rowHeight + rowHeight / 2
        )
    }

    static func path(for points: [GraphPoint], rowHeight: CGFloat, laneWidth: CGFloat) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        let firstPosition = CGPoint(
            x: CGFloat(first.lane) * laneWidth + laneWidth / 2,
            y: CGFloat(first.row) * rowHeight + rowHeight / 2
        )
        path.move(to: firstPosition)

        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let prevPosition = CGPoint(
                x: CGFloat(prev.lane) * laneWidth + laneWidth / 2,
                y: CGFloat(prev.row) * rowHeight + rowHeight / 2
            )
            let currPosition = CGPoint(
                x: CGFloat(curr.lane) * laneWidth + laneWidth / 2,
                y: CGFloat(curr.row) * rowHeight + rowHeight / 2
            )

            if prev.lane != curr.lane {
                let laneDelta = abs(curr.lane - prev.lane)
                let cornerRadius = min(4, min(CGFloat(laneDelta) * laneWidth / 2, rowHeight / 2))
                let xDirection = CGFloat(curr.lane > prev.lane ? 1 : -1)
                let yDirection = CGFloat(curr.row > prev.row ? 1 : -1)

                let preTurn = CGPoint(x: currPosition.x - xDirection * cornerRadius, y: prevPosition.y)
                let postTurn = CGPoint(x: currPosition.x, y: prevPosition.y + yDirection * cornerRadius)
                let corner = CGPoint(x: currPosition.x, y: prevPosition.y)

                path.addLine(to: preTurn)
                path.addQuadCurve(to: postTurn, control: corner)
                path.addLine(to: currPosition)
            } else {
                path.addLine(to: currPosition)
            }
        }

        return path
    }
}
