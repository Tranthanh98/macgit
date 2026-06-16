//
//  ToolbarAction.swift
//  macgit
//

import SwiftUI

enum ToolbarAction: Hashable {
    case commit, pull, push, fetch, branch, merge, stash, search
}

struct ToolbarActionState: Equatable {
    let isSyncing: Bool
    let stagedCount: Int
    let stashableCount: Int
}

extension Notification.Name {
    static let toolbarAction = Notification.Name("macgit.toolbarAction")
}

struct ToolbarActionKey: FocusedValueKey {
    typealias Value = Binding<ToolbarAction>
}

struct ToolbarActionStateKey: FocusedValueKey {
    typealias Value = ToolbarActionState
}

extension FocusedValues {
    var toolbarAction: Binding<ToolbarAction>? {
        get { self[ToolbarActionKey.self] }
        set { self[ToolbarActionKey.self] = newValue }
    }

    var toolbarActionState: ToolbarActionState? {
        get { self[ToolbarActionStateKey.self] }
        set { self[ToolbarActionStateKey.self] = newValue }
    }
}
