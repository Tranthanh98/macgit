//
//  AppState.swift
//  macgit
//
//  Created by AI Assistant on 30/5/26.
//

import SwiftUI
import Combine

enum FileMenuAction: Equatable {
    case new
    case open
    case close
    case openRecent(URL)
}

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var fileMenuAction: FileMenuAction?
    @Published var openWindowWithCloneSheet = false
    @Published var newWindowRepoURL: URL?
    @Published var hasOpenRepository = false

    private init() {}
}
