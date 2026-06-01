//
//  BranchGraphCanvas.swift
//  macgit
//

import SwiftUI

struct BranchGraphCanvas: View {
    let nodes: [GraphNode]
    let edges: [GraphEdge]
    let laneCount: Int

    let rowHeight: CGFloat = 32
    let laneWidth: CGFloat = 14
    let dotSize: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            guard !nodes.isEmpty else { return }

            // 1. Draw edges (lines / curves)
            for edge in edges {
                let y1 = CGFloat(edge.fromRow) * rowHeight + rowHeight / 2
                let x1 = CGFloat(edge.fromLane) * laneWidth + laneWidth / 2
                let y2 = CGFloat(edge.toRow) * rowHeight + rowHeight / 2
                let x2 = CGFloat(edge.toLane) * laneWidth + laneWidth / 2

                let color: Color
                if edge.fromLane == edge.toLane {
                    color = LaneColors.color(for: edge.fromLane)
                } else if edge.isMergeParent {
                    color = LaneColors.color(for: edge.toLane)
                } else {
                    color = LaneColors.color(for: edge.fromLane)
                }

                var path = Path()
                path.move(to: CGPoint(x: x1, y: y1))

                if edge.fromLane == edge.toLane {
                    // Straight vertical line
                    path.addLine(to: CGPoint(x: x2, y: y2))
                } else {
                    // Curved connector
                    let dy = y2 - y1
                    let ady = abs(dy)
                    let minStraight = rowHeight * 0.5
                    let curveSpan = rowHeight * 0.6

                    if ady > curveSpan + minStraight * 2 {
                        if !edge.isMergeParent {
                            // First-parent: straight down in child's lane, curve into parent at the bottom
                            let straightEndY = y2 - (dy > 0 ? curveSpan : -curveSpan)
                            path.addLine(to: CGPoint(x: x1, y: straightEndY))

                            let cp1 = CGPoint(
                                x: x1,
                                y: straightEndY + (dy > 0 ? curveSpan * 0.35 : -curveSpan * 0.35)
                            )
                            let cp2 = CGPoint(
                                x: x2,
                                y: y2 + (dy > 0 ? -curveSpan * 0.35 : curveSpan * 0.35)
                            )
                            path.addCurve(to: CGPoint(x: x2, y: y2), control1: cp1, control2: cp2)
                        } else {
                            // Merge source: curve near child, then straight down in parent's lane
                            let straightStartY = y1 + (dy > 0 ? curveSpan : -curveSpan)
                            let cp1 = CGPoint(
                                x: x1,
                                y: y1 + (dy > 0 ? curveSpan * 0.35 : -curveSpan * 0.35)
                            )
                            let cp2 = CGPoint(
                                x: x2,
                                y: straightStartY + (dy > 0 ? -curveSpan * 0.35 : curveSpan * 0.35)
                            )
                            path.addCurve(
                                to: CGPoint(x: x2, y: straightStartY),
                                control1: cp1,
                                control2: cp2
                            )
                            path.addLine(to: CGPoint(x: x2, y: y2))
                        }
                    } else {
                        // Short descent: wide bezier with vertical pull
                        let tension = max(abs(x2 - x1) * 0.5, ady * 0.35, rowHeight * 0.6)
                        let cp1 = CGPoint(
                            x: x1,
                            y: y1 + (dy > 0 ? min(tension, ady * 0.45) : -min(tension, ady * 0.45))
                        )
                        let cp2 = CGPoint(
                            x: x2,
                            y: y2 + (dy > 0 ? -min(tension, ady * 0.45) : min(tension, ady * 0.45))
                        )
                        path.addCurve(to: CGPoint(x: x2, y: y2), control1: cp1, control2: cp2)
                    }
                }

                context.stroke(path, with: .color(color), lineWidth: 2.2)
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
}
