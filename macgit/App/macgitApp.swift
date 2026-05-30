//
//  macgitApp.swift
//  macgit
//
//  Created by Thanh Tran on 26/5/26.
//

import SwiftUI

@main
struct macgitApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New...") {
                    appState.fileMenuAction = .new
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open...") {
                    appState.fileMenuAction = .open
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Menu("Open Recent") {
                    let recents = Array(RecentRepositoriesStore.shared.repositories.prefix(10))
                    if recents.isEmpty {
                        Text("No Recent Repositories")
                    } else {
                        ForEach(recents) { repo in
                            Button(repo.name) {
                                appState.fileMenuAction = .openRecent(repo.url)
                            }
                        }
                    }
                }

                Divider()

                Button("Close") {
                    appState.fileMenuAction = .close
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(!appState.hasOpenRepository)
            }
        }
    }
}
