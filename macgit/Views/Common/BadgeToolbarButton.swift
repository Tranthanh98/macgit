//
//  BadgeToolbarButton.swift
//  macgit
//

import SwiftUI

struct BadgeToolbarButton: View {
    let icon: String
    let label: String
    let badgeCount: Int
    let action: () -> Void

    private var badgeText: String {
        if badgeCount > 99 {
            return "99+"
        }
        return String(badgeCount)
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                ToolbarButtonLabel(icon: icon, label: label)
                    .frame(minWidth: 44)

                if badgeCount > 0 {
                    Text(badgeText)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1)
                        )
                        .offset(x: 8, y: -4)
                }
            }
        }
        .help(label)
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        BadgeToolbarButton(icon: "checkmark", label: "Commit", badgeCount: 3, action: {})
        BadgeToolbarButton(icon: "arrow.up.to.line", label: "Push", badgeCount: 105, action: {})
        BadgeToolbarButton(icon: "arrow.down.to.line", label: "Pull", badgeCount: 0, action: {})
    }
    .padding()
}
