//
//  FetchSheetView.swift
//  macgit
//

import SwiftUI

struct FetchSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let repositoryURL: URL
    let onFetch: (GitStatusService.FetchOptions) -> Void

    @State private var fetchAllRemotes = true
    @State private var pruneBranches = false
    @State private var fetchTags = false

    private var fetchOptions: GitStatusService.FetchOptions {
        GitStatusService.FetchOptions(
            fetchAllRemotes: fetchAllRemotes,
            prune: pruneBranches,
            fetchTags: fetchTags
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Fetch from all remotes", isOn: $fetchAllRemotes)
                        .font(.system(size: 13))
                        .toggleStyle(.checkbox)

                    Toggle("Prune tracking branches no longer present on remote(s)", isOn: $pruneBranches)
                        .font(.system(size: 13))
                        .toggleStyle(.checkbox)

                    Toggle("Fetch and store all tags locally", isOn: $fetchTags)
                        .font(.system(size: 13))
                        .toggleStyle(.checkbox)
                }
                .padding(12)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(24)

            Spacer()

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("OK") {
                    dismiss()
                    onFetch(fetchOptions)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(GlassProminentButtonStyle(tint: .accentColor, fontSize: 13))
            }
            .padding([.horizontal, .bottom], 24)
        }
        .frame(minWidth: 420, idealWidth: 420, maxWidth: 420)
        .frame(minHeight: 200, idealHeight: 220)
    }
}

#Preview {
    FetchSheetView(repositoryURL: URL(fileURLWithPath: "/tmp")) { _ in }
}
