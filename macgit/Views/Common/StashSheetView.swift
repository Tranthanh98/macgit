//
//  StashSheetView.swift
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

struct StashSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let onStash: (GitStatusService.StashOptions) -> Void

    @State private var message: String = ""
    @State private var keepStagedChanges: Bool = false

    private var stashOptions: GitStatusService.StashOptions {
        GitStatusService.StashOptions(
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            keepIndex: keepStagedChanges
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("This will stash all the changes in your working copy and return it to a clean state.")
                    .font(.system(size: 13))

                HStack(spacing: 8) {
                    Text("Message:")
                        .font(.system(size: 13))
                    TextField("Optional", text: $message)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Keep staged changes", isOn: $keepStagedChanges)
                    .font(.system(size: 13))
                    .toggleStyle(.checkbox)
            }
            .padding(24)

            Spacer()

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Stash") {
                    dismiss()
                    onStash(stashOptions)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(GlassProminentButtonStyle(tint: .accentColor, fontSize: 13))
            }
            .padding([.horizontal, .bottom], 24)
        }
        .frame(minWidth: 420, idealWidth: 480, maxWidth: 520)
        .frame(minHeight: 180, idealHeight: 200)
    }
}

#Preview {
    StashSheetView { _ in }
}
