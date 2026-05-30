//
//  SyncState.swift
//  macgit
//

import SwiftUI
import Combine

class SyncState: ObservableObject {
    @Published var commitBadgeCount: Int = 0
    @Published var pushBadgeCount: Int = 0
    @Published var pullBadgeCount: Int = 0
    @Published var errorMessage: String? = nil
    @Published var showingError: Bool = false
    @Published var conflictMessage: String? = nil
    @Published var showingConflict: Bool = false

    private var backgroundTask: Task<Void, Never>? = nil

    func refresh(repositoryURL: URL) async {
        do {
            let status = try await GitStatusService.shared.status(for: repositoryURL)
            let totalChanges = status.staged.count + status.unstaged.count + status.untracked.count
            let counts = await GitStatusService.shared.aheadBehindCount(in: repositoryURL)
            await MainActor.run {
                self.commitBadgeCount = totalChanges
                self.pushBadgeCount = counts.ahead
                self.pullBadgeCount = counts.behind
            }
        } catch {
            // Silently ignore refresh failures to avoid spamming the user
        }
    }

    func startBackgroundSync(repositoryURL: URL) {
        stopBackgroundSync()
        backgroundTask = Task {
            while !Task.isCancelled {
                await refresh(repositoryURL: repositoryURL)
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            }
        }
    }

    func stopBackgroundSync() {
        backgroundTask?.cancel()
        backgroundTask = nil
    }

    func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }

    func showConflict(_ message: String) {
        conflictMessage = message
        showingConflict = true
    }

    func checkConflicts(repositoryURL: URL) async -> Bool {
        let hasConflicts = await GitStatusService.shared.hasConflicts(in: repositoryURL)
        if hasConflicts {
            showConflict("There are unresolved merge conflicts. Please resolve them before proceeding.")
        }
        return hasConflicts
    }

    func performPush(repositoryURL: URL) async {
        if await checkConflicts(repositoryURL: repositoryURL) { return }
        do {
            try await GitStatusService.shared.push(in: repositoryURL)
            await refresh(repositoryURL: repositoryURL)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func performPull(repositoryURL: URL) async {
        if await checkConflicts(repositoryURL: repositoryURL) { return }
        do {
            try await GitStatusService.shared.pull(in: repositoryURL)
            await refresh(repositoryURL: repositoryURL)
        } catch {
            let message = error.localizedDescription
            if message.uppercased().contains("CONFLICT") {
                showConflict("Merge conflicts occurred during Pull. Please resolve them in the File status view.")
            } else {
                showError(message)
            }
        }
    }

    func performFetch(repositoryURL: URL) async {
        do {
            try await GitStatusService.shared.fetch(in: repositoryURL)
            await refresh(repositoryURL: repositoryURL)
        } catch {
            showError(error.localizedDescription)
        }
    }
}
