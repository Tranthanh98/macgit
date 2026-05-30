//
//  ContentView.swift
//  macgit
//
//  Created by Thanh Tran on 26/5/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    @State private var repositoryURL: URL?
    @State private var showingRepoPickerSheet = false
    @State private var repoPickerShowCloneInitially = false
    @State private var showingKeepCurrentAlert = false
    @State private var pendingAction: FileMenuAction?

    var body: some View {
        Group {
            if let url = repositoryURL {
                MainWindowView(repositoryURL: url)
            } else {
                RepoPickerView(
                    showCloneSheetInitially: repoPickerShowCloneInitially,
                    onRepositoryOpened: { url in
                        repositoryURL = url
                        repoPickerShowCloneInitially = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingRepoPickerSheet) {
            RepoPickerView(
                showCloneSheetInitially: repoPickerShowCloneInitially,
                onRepositoryOpened: { url in
                    showingRepoPickerSheet = false
                    repoPickerShowCloneInitially = false
                    repositoryURL = url
                }
            )
            .frame(minWidth: 560, minHeight: 480)
        }
        .alert("Current Repository is Open", isPresented: $showingKeepCurrentAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Close Current", role: .destructive) {
                closeCurrentAndPerformPending()
            }
            Button("Keep Open") {
                openNewWindowForPending()
            }
        } message: {
            Text("Do you want to keep the current repository open?")
        }
        .onChange(of: appState.fileMenuAction) { _, newValue in
            guard let action = newValue else { return }
            appState.fileMenuAction = nil

            switch action {
            case .new, .open, .openRecent:
                if repositoryURL != nil {
                    pendingAction = action
                    showingKeepCurrentAlert = true
                } else {
                    performAction(action, inNewWindow: false)
                }
            case .close:
                repositoryURL = nil
            }
        }
        .onChange(of: repositoryURL) { _, newValue in
            appState.hasOpenRepository = newValue != nil
        }
        .onAppear {
            appState.hasOpenRepository = repositoryURL != nil
            handlePendingWindowFlags()
        }
    }

    private func handlePendingWindowFlags() {
        if let url = appState.newWindowRepoURL {
            repositoryURL = url
            appState.newWindowRepoURL = nil
        }
        if appState.openWindowWithCloneSheet {
            repoPickerShowCloneInitially = true
            appState.openWindowWithCloneSheet = false
            if repositoryURL == nil {
                showingRepoPickerSheet = true
            }
        }
    }

    private func performAction(_ action: FileMenuAction, inNewWindow: Bool) {
        switch action {
        case .new:
            if inNewWindow {
                appState.openWindowWithCloneSheet = true
                openWindow(id: "main")
            } else {
                repoPickerShowCloneInitially = true
                showingRepoPickerSheet = true
            }
        case .open:
            if inNewWindow {
                openWindow(id: "main")
            } else {
                repoPickerShowCloneInitially = false
                showingRepoPickerSheet = true
            }
        case .openRecent(let url):
            if inNewWindow {
                appState.newWindowRepoURL = url
                openWindow(id: "main")
            } else {
                repositoryURL = url
            }
        case .close:
            repositoryURL = nil
        }
    }

    private func closeCurrentAndPerformPending() {
        repositoryURL = nil
        if let action = pendingAction {
            performAction(action, inNewWindow: false)
            pendingAction = nil
        }
    }

    private func openNewWindowForPending() {
        if let action = pendingAction {
            performAction(action, inNewWindow: true)
            pendingAction = nil
        }
    }
}
