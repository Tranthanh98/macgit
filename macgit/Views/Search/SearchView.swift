//
//  SearchView.swift
//  macgit
//

import SwiftUI

struct SearchView: View {
    let repositoryURL: URL

    var body: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            message: "Search across commits, files, and branches",
            detail: repositoryURL.path
        )
    }
}
