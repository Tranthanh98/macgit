import SwiftUI

struct SearchView: View {
    let repositoryURL: URL

    var body: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            message: "Quick Search",
            detail: "Press ⌘⇧F to search across commits, files, branches, and tags"
        )
    }
}
