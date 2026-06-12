//
//  BranchFilterBar.swift
//  macgit
//

import SwiftUI

struct BranchFilterBar: View {
    @Binding var showAllBranches: Bool
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Picker("Branch Filter", selection: $showAllBranches) {
                Text("All Branches").tag(true)
                Text("Current Branch").tag(false)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 160)
            .padding(.leading, 8)

            Spacer()
        }
        .padding(.trailing, 16)
        .frame(height: 28)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 0.5)
        }
        .onChange(of: showAllBranches) { _, _ in
            onChange()
        }
    }
}

struct ColumnResizer: View {
    @Binding var leftWidth: CGFloat
    @Binding var rightWidth: CGFloat
    @State private var initialLeft: CGFloat = 0
    @State private var initialRight: CGFloat = 0
    /// Whether the right side is a real column (true) or empty space (false)
    private var hasRightColumn: Bool { rightWidth > 10 }

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 6)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if initialLeft == 0 {
                            initialLeft = leftWidth
                            initialRight = rightWidth
                        }
                        let delta = value.translation.width
                        if hasRightColumn {
                            // Standard two-column resizer: space moves from right to left
                            let maxExpand = initialRight - 40
                            let actualDelta = max(-(initialLeft - 40), min(delta, maxExpand))
                            leftWidth = initialLeft + actualDelta
                            rightWidth = initialRight - actualDelta
                        } else {
                            // Last resizer: only clamp left column minimum
                            let actualDelta = max(-(initialLeft - 40), delta)
                            leftWidth = initialLeft + actualDelta
                        }
                    }
                    .onEnded { _ in
                        initialLeft = 0
                        initialRight = 0
                    }
            )
            .overlay(
                Rectangle()
                    .fill(.separator)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            )
    }
}
