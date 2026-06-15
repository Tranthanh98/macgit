//
//  BranchFetchActionPolicy.swift
//  macgit
//

import Foundation

enum BranchFetchActionPolicy {
    static func shouldEnableFetch(for status: BranchSyncStatus?) -> Bool {
        (status?.behind ?? 0) > 0
    }
}
