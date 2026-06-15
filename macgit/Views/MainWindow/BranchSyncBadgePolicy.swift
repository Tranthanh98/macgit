//
//  BranchSyncBadgePolicy.swift
//  macgit
//

import Foundation

enum BranchSyncBadgePolicy {
    static func shouldShowLoading(
        for branch: String,
        isPulling: Bool,
        isPushing: Bool,
        activeSyncBranch: String?
    ) -> Bool {
        (isPulling || isPushing) && activeSyncBranch == branch
    }
}
