//
//  StashActionConfirmationSheet.swift
//  macgit
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

enum StashAction: Equatable {
    case apply
    case delete

    var title: String {
        switch self {
        case .apply:
            return "Apply Stash"
        case .delete:
            return "Delete Stash"
        }
    }

    var message: String {
        switch self {
        case .apply:
            return "Apply the selected stash to your working copy."
        case .delete:
            return "This will permanently remove the stash entry."
        }
    }

    var buttonTitle: String {
        switch self {
        case .apply:
            return "Apply"
        case .delete:
            return "Delete"
        }
    }

    var buttonTint: Color {
        switch self {
        case .apply:
            return .accentColor
        case .delete:
            return .red
        }
    }
}

struct StashActionConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let stashRef: String
    let action: StashAction
    let onConfirm: (Bool) -> Void

    @State private var deleteAfterApplying = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(action == .delete ? .red : .blue)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: action == .delete ? "trash" : "tray.and.arrow.down")
                                .font(.system(size: 26))
                                .foregroundStyle(.white)
                        )

                    Text(action.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(action.message)
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)

                    Text(stashRef)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.quaternary.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if action == .apply {
                        Toggle("Delete after applying", isOn: $deleteAfterApplying)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 13))
                            .frame(maxWidth: 340, alignment: .leading)
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)
            }

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                if action == .delete {
                    Button(action.buttonTitle, role: .destructive) {
                        dismiss()
                        onConfirm(false)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(GlassProminentButtonStyle(tint: action.buttonTint, fontSize: 13))
                } else {
                    Button(action.buttonTitle) {
                        dismiss()
                        onConfirm(deleteAfterApplying)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(GlassProminentButtonStyle(tint: action.buttonTint, fontSize: 13))
                }
            }
            .padding([.horizontal, .bottom], 24)
        }
        .frame(minWidth: 420, idealWidth: 460, maxWidth: 500)
        .frame(minHeight: 260, idealHeight: 300)
    }
}

#Preview {
    StashActionConfirmationSheet(stashRef: "stash@{0}", action: .apply) { _ in }
}
