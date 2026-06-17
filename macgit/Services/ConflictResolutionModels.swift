//
//  ConflictResolutionModels.swift
//  macgit
//

import Foundation

enum ConflictSectionResolution: String, CaseIterable {
    case current
    case incoming
    case both
    case manual
}

enum ConflictSectionKind: Equatable {
    case context
    case conflict
}

struct ConflictResolutionSection: Identifiable, Equatable {
    let id = UUID()
    let kind: ConflictSectionKind
    var contextText: String
    var currentText: String
    var incomingText: String
    var resolution: ConflictSectionResolution
    var manualResult: String

    var isConflict: Bool {
        kind == .conflict
    }

    var preferredResultText: String {
        switch resolution {
        case .current:
            return currentText
        case .incoming:
            return incomingText
        case .both:
            return currentText + incomingText
        case .manual:
            return manualResult
        }
    }

    var editorText: String {
        guard isConflict else { return contextText }
        if !manualResult.isEmpty {
            return manualResult
        }
        return preferredResultText
    }

    var resolvedText: String {
        isConflict ? editorText : contextText
    }

    var currentPaneText: String {
        isConflict ? currentText : contextText
    }

    var incomingPaneText: String {
        isConflict ? incomingText : contextText
    }

    static func context(_ text: String) -> ConflictResolutionSection {
        ConflictResolutionSection(
            kind: .context,
            contextText: text,
            currentText: "",
            incomingText: "",
            resolution: .manual,
            manualResult: ""
        )
    }

    static func conflict(current: String, incoming: String) -> ConflictResolutionSection {
        ConflictResolutionSection(
            kind: .conflict,
            contextText: "",
            currentText: current,
            incomingText: incoming,
            resolution: .current,
            manualResult: ""
        )
    }
}

struct ConflictResolutionDocument: Equatable {
    var sections: [ConflictResolutionSection]
    var currentContent: String
    var incomingContent: String

    var conflictCount: Int {
        sections.filter(\.isConflict).count
    }

    var resolvedText: String {
        sections.map(\.resolvedText).joined()
    }

    static func parse(
        _ text: String,
        currentContent: String? = nil,
        incomingContent: String? = nil
    ) throws -> ConflictResolutionDocument {
        enum ParseState {
            case context
            case current
            case incoming
        }

        let lines = splitPreservingNewlines(in: text)
        var sections: [ConflictResolutionSection] = []
        var contextBuffer = ""
        var currentBuffer = ""
        var incomingBuffer = ""
        var state: ParseState = .context

        func flushContext() {
            guard !contextBuffer.isEmpty else { return }
            sections.append(.context(contextBuffer))
            contextBuffer = ""
        }

        func flushConflict() {
            sections.append(.conflict(current: currentBuffer, incoming: incomingBuffer))
            currentBuffer = ""
            incomingBuffer = ""
        }

        for line in lines {
            switch state {
            case .context:
                if line.hasPrefix("<<<<<<<") {
                    flushContext()
                    state = .current
                } else {
                    contextBuffer += line
                }
            case .current:
                if line.hasPrefix("=======") {
                    state = .incoming
                } else {
                    currentBuffer += line
                }
            case .incoming:
                if line.hasPrefix(">>>>>>>") {
                    flushConflict()
                    state = .context
                } else {
                    incomingBuffer += line
                }
            }
        }

        guard state == .context else {
            throw GitError.commandFailed("Could not parse conflict markers in file.")
        }

        flushContext()

        let resolvedCurrent = currentContent ?? sections.map(\.currentPaneText).joined()
        let resolvedIncoming = incomingContent ?? sections.map(\.incomingPaneText).joined()

        return ConflictResolutionDocument(
            sections: sections,
            currentContent: resolvedCurrent,
            incomingContent: resolvedIncoming
        )
    }

    private static func splitPreservingNewlines(in text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        var fragments: [String] = []
        var lineStart = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            if text[index] == "\n" {
                let nextIndex = text.index(after: index)
                fragments.append(String(text[lineStart..<nextIndex]))
                lineStart = nextIndex
                index = nextIndex
            } else {
                text.formIndex(after: &index)
            }
        }

        if lineStart < text.endIndex {
            fragments.append(String(text[lineStart..<text.endIndex]))
        }

        return fragments
    }
}
