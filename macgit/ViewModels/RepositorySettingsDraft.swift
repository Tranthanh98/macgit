//
//  RepositorySettingsDraft.swift
//  macgit
//

import Foundation

enum SelectedBranchMode: String, Equatable {
    case detected
    case manual
}

struct RepositorySettingsDraft: Equatable {
    var selectedRemoteName: String
    var selectedBranchMode: SelectedBranchMode
    var selectedDetectedBranch: String
    var manualBranchName: String
    var pullStrategy: PullStrategy
    var autoFetchEnabled: Bool
    var refreshOnAppActive: Bool
    var confirmDetachedHeadCheckout: Bool
    var confirmDestructiveStashActions: Bool
    let remotes: [String]
    let branches: [String]

    init(
        settings: RepoSettings,
        remotes: [String],
        branches: [String],
        currentBranch: String?
    ) {
        self.remotes = remotes
        self.branches = branches

        selectedRemoteName = Self.resolveRemote(
            savedRemoteName: settings.defaultRemoteName,
            remotes: remotes
        )

        if branches.contains(settings.defaultPullBranch) {
            selectedBranchMode = .detected
            selectedDetectedBranch = settings.defaultPullBranch
            manualBranchName = ""
        } else {
            selectedBranchMode = .manual
            selectedDetectedBranch = Self.resolveDetectedBranch(
                currentBranch: currentBranch,
                branches: branches
            )
            manualBranchName = settings.defaultPullBranch
        }

        pullStrategy = settings.pullStrategy
        autoFetchEnabled = settings.autoFetchEnabled
        refreshOnAppActive = settings.refreshOnAppActive
        confirmDetachedHeadCheckout = settings.confirmDetachedHeadCheckout
        confirmDestructiveStashActions = settings.confirmDestructiveStashActions
    }

    var resolvedSettings: RepoSettings {
        RepoSettings(
            defaultRemoteName: selectedRemoteName.isEmpty ? nil : selectedRemoteName,
            defaultPullBranch: resolvedPullBranch(),
            pullStrategy: pullStrategy,
            autoFetchEnabled: autoFetchEnabled,
            refreshOnAppActive: refreshOnAppActive,
            confirmDetachedHeadCheckout: confirmDetachedHeadCheckout,
            confirmDestructiveStashActions: confirmDestructiveStashActions
        )
    }

    private func resolvedPullBranch() -> String {
        switch selectedBranchMode {
        case .detected:
            return selectedDetectedBranch
        case .manual:
            return manualBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func resolveRemote(savedRemoteName: String?, remotes: [String]) -> String {
        if let savedRemoteName, remotes.contains(savedRemoteName) {
            return savedRemoteName
        }
        return remotes.first ?? ""
    }

    private static func resolveDetectedBranch(currentBranch: String?, branches: [String]) -> String {
        if let currentBranch, branches.contains(currentBranch) {
            return currentBranch
        }
        return branches.first ?? ""
    }
}
