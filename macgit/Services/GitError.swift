//
//  GitError.swift
//  macgit
//

import Foundation

enum GitError: LocalizedError {
    case notARepository
    case gitNotFound
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notARepository:
            return "The selected folder is not a Git repository."
        case .gitNotFound:
            return "Git command not found. Please install Git."
        case .commandFailed(let message):
            return message
        }
    }
}
