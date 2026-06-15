//
//  RepoSettings.swift
//  macgit
//

import Foundation

enum PullStrategy: String, Codable, CaseIterable {
    case merge
    case rebase
}

struct RepoSettings: Codable, Equatable {
    var defaultRemoteName: String?
    var defaultPullBranch: String
    var pullStrategy: PullStrategy
    var autoFetchEnabled: Bool
    var refreshOnAppActive: Bool
    var confirmDetachedHeadCheckout: Bool
    var confirmDestructiveStashActions: Bool

    init(
        defaultRemoteName: String? = nil,
        defaultPullBranch: String,
        pullStrategy: PullStrategy = .merge,
        autoFetchEnabled: Bool = false,
        refreshOnAppActive: Bool = true,
        confirmDetachedHeadCheckout: Bool = true,
        confirmDestructiveStashActions: Bool = true
    ) {
        self.defaultRemoteName = defaultRemoteName
        self.defaultPullBranch = defaultPullBranch
        self.pullStrategy = pullStrategy
        self.autoFetchEnabled = autoFetchEnabled
        self.refreshOnAppActive = refreshOnAppActive
        self.confirmDetachedHeadCheckout = confirmDetachedHeadCheckout
        self.confirmDestructiveStashActions = confirmDestructiveStashActions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultRemoteName = try container.decodeIfPresent(String.self, forKey: .defaultRemoteName)
        defaultPullBranch = try container.decodeIfPresent(String.self, forKey: .defaultPullBranch) ?? ""
        pullStrategy = try container.decodeIfPresent(PullStrategy.self, forKey: .pullStrategy) ?? .merge
        autoFetchEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoFetchEnabled) ?? false
        refreshOnAppActive = try container.decodeIfPresent(Bool.self, forKey: .refreshOnAppActive) ?? true
        confirmDetachedHeadCheckout = try container.decodeIfPresent(Bool.self, forKey: .confirmDetachedHeadCheckout) ?? true
        confirmDestructiveStashActions = try container.decodeIfPresent(Bool.self, forKey: .confirmDestructiveStashActions) ?? true
    }

    static func defaults(currentBranch: String?, remotes: [String]) -> RepoSettings {
        RepoSettings(
            defaultRemoteName: remotes.first,
            defaultPullBranch: currentBranch ?? ""
        )
    }
}
