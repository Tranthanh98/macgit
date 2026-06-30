//
//  GitDragActionConfirmationSheet.swift
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

struct GitDragActionConfirmationSheet: View {
    let title: String
    let message: String
    let sourceBranchName: String?
    let targetBranchName: String
    let commits: [GitDraggedCommit]
    let primaryActionTitle: String
    let selectedBranchOperation: Binding<GitDragBranchOperation>?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    init(
        title: String = "Confirm Commit Drop",
        message: String = "Review the commits before continuing.",
        sourceBranchName: String? = nil,
        targetBranchName: String,
        commits: [GitDraggedCommit],
        primaryActionTitle: String = "Continue",
        selectedBranchOperation: Binding<GitDragBranchOperation>? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.sourceBranchName = sourceBranchName
        self.targetBranchName = targetBranchName
        self.commits = commits
        self.primaryActionTitle = primaryActionTitle
        self.selectedBranchOperation = selectedBranchOperation
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            if let operation = selectedBranchOperation, let sourceBranchName {
                branchOperationContent(sourceBranchName: sourceBranchName, operation: operation)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target branch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    branchNamePill(targetBranchName)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Commits")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(commits.enumerated()), id: \.element.hash) { index, commit in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(index + 1). \(commit.hash)")
                                        .font(.system(size: 12, weight: .medium))
                                    Text(commit.message)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(minHeight: 120, maxHeight: 220)
                }
            }

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button(primaryActionTitle, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(GlassProminentButtonStyle(tint: .accentColor, fontSize: 13))
            }
        }
        .padding(24)
        .frame(minWidth: 420, idealWidth: 480, maxWidth: 560)
    }

    @ViewBuilder
    private func branchOperationContent(
        sourceBranchName: String,
        operation: Binding<GitDragBranchOperation>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Branches")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .center, spacing: 10) {
                    branchEndpoint(title: "Source", branchName: sourceBranchName)
                    Image(systemName: "arrow.right")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    branchEndpoint(title: "Target", branchName: targetBranchName)
                }
                .padding(12)
                .background(.quaternary.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Operation")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("", selection: operation) {
                    Text("Merge \(sourceBranchName) into \(targetBranchName)")
                        .tag(GitDragBranchOperation.merge)
                    Text("Rebase \(targetBranchName) onto \(sourceBranchName)")
                        .tag(GitDragBranchOperation.rebase)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
        }
    }

    private func branchEndpoint(title: String, branchName: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            branchNamePill(branchName)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func branchNamePill(_ branchName: String) -> some View {
        Text(branchName)
            .font(.subheadline.bold())
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    GitDragActionConfirmationSheet(
        targetBranchName: "main",
        commits: [
            GitDraggedCommit(hash: "a1b2c3d", message: "Add commit drag policy", isMerge: false),
            GitDraggedCommit(hash: "d4e5f6g", message: "Refine drop affordances", isMerge: false)
        ],
        primaryActionTitle: "Cherry-pick",
        onConfirm: {},
        onCancel: {}
    )
}
