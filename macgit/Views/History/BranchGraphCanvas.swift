//
//  BranchGraphCanvas.swift
//  macgit
//

import SwiftUI

struct BranchGraphCanvas: View {
    let nodes: [GraphNode]
    let rowHeight: CGFloat = 32
    let laneWidth: CGFloat = 14
    let dotSize: CGFloat = 8
    
    var body: some View {
        Canvas { context, size in
            guard !nodes.isEmpty else { return }
            
            let maxLane = nodes.map(\.lane).max() ?? 0
            _ = maxLane
            
            // Draw connecting lines first (behind dots)
            for (i, node) in nodes.enumerated() {
                let y1 = CGFloat(i) * rowHeight + rowHeight / 2
                let x1 = CGFloat(node.lane) * laneWidth + laneWidth / 2
                
                for parentHash in node.commit.parents {
                    guard let parentIndex = nodes.firstIndex(where: { $0.commit.hash == parentHash }) else { continue }
                    let parentNode = nodes[parentIndex]
                    let y2 = CGFloat(parentIndex) * rowHeight + rowHeight / 2
                    let x2 = CGFloat(parentNode.lane) * laneWidth + laneWidth / 2
                    
                    let color = LaneColors.color(for: node.lane)
                    var path = Path()
                    path.move(to: CGPoint(x: x1, y: y1))
                    
                    if abs(x2 - x1) < 0.5 {
                        // Same lane: straight vertical line
                        path.addLine(to: CGPoint(x: x2, y: y2))
                    } else {
                        let dx = x2 - x1
                        let dy = y2 - y1
                        let ady = abs(dy)
                        let minStraight = rowHeight * 0.5  // minimum straight before curve
                        let curveSpan = rowHeight * 0.6   // how tall the curve zone is
                        
                        if ady > curveSpan + minStraight * 2 {
                            // Plenty of room: long straight + short rounded curve at end
                            // Go straight along child's lane almost to parent row
                            let straightEndY = y2 - (dy > 0 ? curveSpan : -curveSpan)
                            path.addLine(to: CGPoint(x: x1, y: straightEndY))
                            
                            // Short smooth curve into parent lane
                            let cp1 = CGPoint(x: x1, y: straightEndY + (dy > 0 ? curveSpan * 0.35 : -curveSpan * 0.35))
                            let cp2 = CGPoint(x: x2, y: y2 + (dy > 0 ? -curveSpan * 0.35 : curveSpan * 0.35))
                            path.addCurve(to: CGPoint(x: x2, y: y2), control1: cp1, control2: cp2)
                        } else {
                            // Not much room: wide single bezier with vertical-pull CPs
                            let tension = max(abs(dx) * 0.5, ady * 0.35, rowHeight * 0.6)
                            let cp1 = CGPoint(x: x1, y: y1 + (dy > 0 ? min(tension, ady * 0.45) : -min(tension, ady * 0.45)))
                            let cp2 = CGPoint(x: x2, y: y2 + (dy > 0 ? -min(tension, ady * 0.45) : min(tension, ady * 0.45)))
                            path.addCurve(to: CGPoint(x: x2, y: y2), control1: cp1, control2: cp2)
                        }
                    }
                    
                    context.stroke(path, with: .color(color), lineWidth: 2.2)
                }
            }
            
            // Draw dots on top
            for (i, node) in nodes.enumerated() {
                let y = CGFloat(i) * rowHeight + rowHeight / 2
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
        let maxLane = nodes.map(\.lane).max() ?? 0
        return CGFloat(maxLane + 1) * laneWidth + 8
    }
}
