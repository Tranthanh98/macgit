//
//  MainWindowView.swift
//  macgit
//
//  Created by Thanh Tran on 26/5/26.
//

import SwiftUI

struct MainWindowView: View {
    let repositoryURL: URL
    @State private var selectedItem: SidebarItem? = .fileStatus

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedItem)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
        } detail: {
            Group {
                switch selectedItem {
                case .fileStatus:
                    FileStatusView(repositoryURL: repositoryURL)
                case .history:
                    HistoryView(repositoryURL: repositoryURL)
                case .search:
                    SearchView(repositoryURL: repositoryURL)
                case .none:
                    EmptyStateView(message: "Select an item from the sidebar")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(repositoryURL.lastPathComponent)
                    .font(.headline)
            }
            ToolbarItem(placement: .navigation) {
                Button(action: {}) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

struct FileStatusView: View {
    let repositoryURL: URL

    var body: some View {
        EmptyStateView(
            icon: "doc.text.magnifyingglass",
            message: "File status will appear here",
            detail: repositoryURL.path
        )
    }
}

struct HistoryView: View {
    let repositoryURL: URL

    var body: some View {
        EmptyStateView(
            icon: "clock.arrow.circlepath",
            message: "Commit history will appear here",
            detail: repositoryURL.path
        )
    }
}

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

struct EmptyStateView: View {
    var icon: String = "rectangle.dashed"
    var message: String
    var detail: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.title3)
                .foregroundStyle(.primary)
            if let detail = detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
