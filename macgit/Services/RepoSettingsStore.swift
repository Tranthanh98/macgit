//
//  RepoSettingsStore.swift
//  macgit
//

import Foundation

final class RepoSettingsStore {
    static let shared = RepoSettingsStore()

    private let userDefaults: UserDefaults
    private let key: String
    private var settings: [String: RepoSettings]

    init(userDefaults: UserDefaults = .standard, key: String = "com.thanhtran.macgit.repoSettings") {
        self.userDefaults = userDefaults
        self.key = key
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: RepoSettings].self, from: data) {
            settings = decoded
        } else {
            settings = [:]
        }
    }

    func settings(for repositoryPath: String, currentBranch: String, remotes: [String]) -> RepoSettings {
        settings[repositoryPath] ?? RepoSettings.defaults(currentBranch: currentBranch, remotes: remotes)
    }

    func update(for repositoryPath: String, settings: RepoSettings) {
        self.settings[repositoryPath] = settings
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        userDefaults.set(data, forKey: key)
    }
}
