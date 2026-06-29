//
//  AppState.swift
//  macgit
//
//  Created by AI Assistant on 30/5/26.
//

//
//  macgit (Commit+) - a macOS Git client built with Swift and SwiftUI.
//  Copyright (C) 2026  Thanh Tran <trantienthanh2412@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Affero General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Affero General Public License for more details.
//
//  You should have received a copy of the GNU Affero General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
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
