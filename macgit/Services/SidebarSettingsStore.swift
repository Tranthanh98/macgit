//
//  SidebarSettingsStore.swift
//  macgit
//

import Foundation

struct SidebarSectionState: Codable {
    var branchesExpanded: Bool = true
    var tagsExpanded: Bool = true
    var remotesExpanded: Bool = true
    var stashesExpanded: Bool = true
    var worktreesExpanded: Bool = true

    init(
        branchesExpanded: Bool = true,
        tagsExpanded: Bool = true,
        remotesExpanded: Bool = true,
        stashesExpanded: Bool = true,
        worktreesExpanded: Bool = true
    ) {
        self.branchesExpanded = branchesExpanded
        self.tagsExpanded = tagsExpanded
        self.remotesExpanded = remotesExpanded
        self.stashesExpanded = stashesExpanded
        self.worktreesExpanded = worktreesExpanded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        branchesExpanded = try container.decodeIfPresent(Bool.self, forKey: .branchesExpanded) ?? true
        tagsExpanded = try container.decodeIfPresent(Bool.self, forKey: .tagsExpanded) ?? true
        remotesExpanded = try container.decodeIfPresent(Bool.self, forKey: .remotesExpanded) ?? true
        stashesExpanded = try container.decodeIfPresent(Bool.self, forKey: .stashesExpanded) ?? true
        worktreesExpanded = try container.decodeIfPresent(Bool.self, forKey: .worktreesExpanded) ?? true
    }
}

final class SidebarSettingsStore {
    static let shared = SidebarSettingsStore()
    private let key = "com.thanhtran.macgit.sidebarSettings"

    private var settings: [String: SidebarSectionState] = [:]

    private init() {
        load()
    }

    func state(for repositoryPath: String) -> SidebarSectionState {
        settings[repositoryPath] ?? SidebarSectionState()
    }

    func update(for repositoryPath: String, state: SidebarSectionState) {
        settings[repositoryPath] = state
        save()
    }

    func toggleSection(_ section: SidebarSection, for repositoryPath: String) {
        var state = self.state(for: repositoryPath)
        switch section {
        case .branches:
            state.branchesExpanded.toggle()
        case .tags:
            state.tagsExpanded.toggle()
        case .remotes:
            state.remotesExpanded.toggle()
        case .stashes:
            state.stashesExpanded.toggle()
        case .worktrees:
            state.worktreesExpanded.toggle()
        default:
            break
        }
        update(for: repositoryPath, state: state)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: SidebarSectionState].self, from: data) else {
            return
        }
        settings = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
