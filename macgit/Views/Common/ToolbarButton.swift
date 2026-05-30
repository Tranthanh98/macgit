//
//  ToolbarButton.swift
//  macgit
//

import SwiftUI

struct ToolbarButtonLabel: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
            Text(label)
                .font(.system(size: 9))
        }
        .frame(minWidth: 44)
    }
}

func toolbarButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        ToolbarButtonLabel(icon: icon, label: label)
    }
    .help(label)
}
