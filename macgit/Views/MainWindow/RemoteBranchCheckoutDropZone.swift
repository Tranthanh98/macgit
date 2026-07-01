//
//  RemoteBranchCheckoutDropZone.swift
//  macgit
//
//  Created by Thanh Tran on 26/5/26.
//

//
//  macgit (Commit+) - a macOS Git client built with Swift and SwiftUI.
//  Copyright (C) 2026  Thanh Tran <trantienthanh2412@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Affero General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Affero General Public License for more details.
//
//  You should have received a copy of the GNU Affero General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import SwiftUI

struct RemoteBranchCheckoutDropZone: View {
    let remoteBranch: String
    let isTargeted: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.circle")
            Text("Drop to Check Out")
                .bold()
            Spacer(minLength: 4)
            Text(remoteBranch)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.55),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Drop \(remoteBranch) to check out as a local branch")
    }
}
