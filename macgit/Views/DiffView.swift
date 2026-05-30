//
//  DiffView.swift
//  macgit
//

import SwiftUI

struct DiffView: View {
    let hunks: [DiffHunk]
    let file: StatusFile?
    let repositoryURL: URL?
    let onRefresh: () -> Void
    let onError: (String) -> Void

    @State private var selectedLineIDs: Set<UUID> = []
    @State private var lastSelectedLineID: UUID?

    var body: some View {
        if hunks.isEmpty {
            EmptyStateView(message: "No diff to display", detail: "Select a file to see changes")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(hunks) { hunk in
                        HunkView(
                            hunk: hunk,
                            file: file,
                            repositoryURL: repositoryURL,
                            selectedLineIDs: $selectedLineIDs,
                            lastSelectedLineID: $lastSelectedLineID,
                            onRefresh: onRefresh,
                            onError: onError
                        )
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

struct HunkView: View {
    let hunk: DiffHunk
    let file: StatusFile?
    let repositoryURL: URL?
    @Binding var selectedLineIDs: Set<UUID>
    @Binding var lastSelectedLineID: UUID?
    let onRefresh: () -> Void
    let onError: (String) -> Void

    private var isStaged: Bool {
        guard let file = file else { return false }
        return file.status == .staged || file.status == .added || file.status == .renamed
    }

    private var isUntracked: Bool {
        file?.status == .untracked
    }

    private var canInteract: Bool {
        !isUntracked && file != nil && repositoryURL != nil
    }

    private var hasSelectedLines: Bool {
        !selectedLineIDs.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk header with action buttons
            HStack(spacing: 12) {
                Text(hunk.header)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)

                Spacer()

                if canInteract {
                    if isStaged {
                        Button("Unstage hunk") {
                            perform {
                                try await GitStatusService.shared.unstage(hunk: hunk, file: file!, in: repositoryURL!)
                            }
                        }
                        .buttonStyle(.link)
                        .controlSize(.small)
                        .font(.system(size: 11))
                        .help("Unstage this hunk")
                    } else {
                        Button("Stage hunk") {
                            perform {
                                try await GitStatusService.shared.stage(hunk: hunk, file: file!, in: repositoryURL!)
                            }
                        }
                        .buttonStyle(.link)
                        .controlSize(.small)
                        .font(.system(size: 11))
                        .help("Stage this hunk")

                        Button("Discard hunk") {
                            perform {
                                try await GitStatusService.shared.discard(hunk: hunk, file: file!, in: repositoryURL!)
                            }
                        }
                        .buttonStyle(.link)
                        .controlSize(.small)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .help("Discard this hunk")
                    }
                }
            }
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.1))
            .contentShape(Rectangle())
            .contextMenu {
                hunkContextMenu
            }

            // Lines
            ForEach(Array(hunk.lines.enumerated()), id: \.element.id) { index, line in
                DiffLineView(
                    line: line,
                    isSelected: selectedLineIDs.contains(line.id)
                )
                .onTapGesture {
                    handleLineTap(at: index)
                }
                .contextMenu {
                    lineContextMenu(for: line)
                }
            }
        }
    }

    private var hunkContextMenu: some View {
        Group {
            if canInteract {
                if isStaged {
                    Button("Unstage Hunk") {
                        perform {
                            try await GitStatusService.shared.unstage(hunk: hunk, file: file!, in: repositoryURL!)
                        }
                    }
                    if hasSelectedLines {
                        Divider()
                        Button("Unstage Selected Lines") {
                            let lines = expandedSelectedLines(for: hunk)
                            perform {
                                try await GitStatusService.shared.unstage(lines: lines, hunk: hunk, file: file!, in: repositoryURL!)
                            }
                        }
                    }
                } else {
                    Button("Stage Hunk") {
                        perform {
                            try await GitStatusService.shared.stage(hunk: hunk, file: file!, in: repositoryURL!)
                        }
                    }
                    Button("Discard Hunk") {
                        perform {
                            try await GitStatusService.shared.discard(hunk: hunk, file: file!, in: repositoryURL!)
                        }
                    }

                    if hasSelectedLines {
                        Divider()
                        Button("Stage Selected Lines") {
                            let lines = expandedSelectedLines(for: hunk)
                            perform {
                                try await GitStatusService.shared.stage(lines: lines, hunk: hunk, file: file!, in: repositoryURL!)
                            }
                        }
                        Button("Discard Selected Lines") {
                            let lines = expandedSelectedLines(for: hunk)
                            perform {
                                try await GitStatusService.shared.discard(lines: lines, hunk: hunk, file: file!, in: repositoryURL!)
                            }
                        }
                    }
                }
            }
        }
    }

    private func lineContextMenu(for line: DiffLine) -> some View {
        Group {
            if canInteract {
                if isStaged {
                    Button("Unstage Hunk") {
                        perform {
                            try await GitStatusService.shared.unstage(hunk: hunk, file: file!, in: repositoryURL!)
                        }
                    }
                    if selectedLineIDs.contains(line.id) && hasSelectedLines {
                        Divider()
                        Button("Unstage Selected Lines") {
                            let lines = expandedSelectedLines(for: hunk)
                            perform {
                                try await GitStatusService.shared.unstage(lines: lines, hunk: hunk, file: file!, in: repositoryURL!)
                            }
                        }
                    }
                } else {
                    Button("Stage Hunk") {
                        perform {
                            try await GitStatusService.shared.stage(hunk: hunk, file: file!, in: repositoryURL!)
                        }
                    }
                    Button("Discard Hunk") {
                        perform {
                            try await GitStatusService.shared.discard(hunk: hunk, file: file!, in: repositoryURL!)
                        }
                    }

                    if selectedLineIDs.contains(line.id) && hasSelectedLines {
                        Divider()
                        Button("Stage Selected Lines") {
                            let lines = expandedSelectedLines(for: hunk)
                            perform {
                                try await GitStatusService.shared.stage(lines: lines, hunk: hunk, file: file!, in: repositoryURL!)
                            }
                        }
                        Button("Discard Selected Lines") {
                            let lines = expandedSelectedLines(for: hunk)
                            perform {
                                try await GitStatusService.shared.discard(lines: lines, hunk: hunk, file: file!, in: repositoryURL!)
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(line.text, forType: .string)
            }
        }
    }

    private func handleLineTap(at index: Int) {
        let line = hunk.lines[index]
        // Only allow selecting added/removed lines
        guard line.type == .added || line.type == .removed else { return }

        let flags = NSEvent.modifierFlags
        let isShift = flags.contains(.shift)
        let isCommand = flags.contains(.command)

        if isShift {
            guard let lastID = lastSelectedLineID,
                  let lastIndex = hunk.lines.firstIndex(where: { $0.id == lastID }) else {
                selectedLineIDs = [line.id]
                lastSelectedLineID = line.id
                return
            }
            let start = min(lastIndex, index)
            let end = max(lastIndex, index)
            // Only select added/removed lines in the range
            let rangeIDs = Set(hunk.lines[start...end].filter { $0.type == .added || $0.type == .removed }.map(\.id))
            if isCommand {
                selectedLineIDs.formSymmetricDifference(rangeIDs)
            } else {
                selectedLineIDs = rangeIDs
            }
            lastSelectedLineID = line.id
        } else if isCommand {
            if selectedLineIDs.contains(line.id) {
                selectedLineIDs.remove(line.id)
            } else {
                selectedLineIDs.insert(line.id)
            }
            lastSelectedLineID = line.id
        } else {
            selectedLineIDs = [line.id]
            lastSelectedLineID = line.id
        }
    }

    /// Expand selection to full contiguous added/removed blocks so that git apply
    /// receives a consistent patch (git cannot apply partial hunks reliably).
    private func expandedSelectedLines(for hunk: DiffHunk) -> [DiffLine] {
        var blocks: [Set<UUID>] = []
        var currentBlock = Set<UUID>()

        for line in hunk.lines {
            switch line.type {
            case .added, .removed:
                currentBlock.insert(line.id)
            case .context, .header:
                if !currentBlock.isEmpty {
                    blocks.append(currentBlock)
                    currentBlock = []
                }
            }
        }
        if !currentBlock.isEmpty {
            blocks.append(currentBlock)
        }

        var expandedIDs = Set<UUID>()
        for block in blocks {
            if !block.isDisjoint(with: selectedLineIDs) {
                expandedIDs.formUnion(block)
            }
        }

        return hunk.lines.filter { expandedIDs.contains($0.id) }
    }

    private func perform(_ operation: @escaping () async throws -> Void) {
        Task {
            do {
                try await operation()
                await MainActor.run {
                    selectedLineIDs.removeAll()
                    onRefresh()
                }
            } catch {
                await MainActor.run {
                    onError(error.localizedDescription)
                }
            }
        }
    }
}

struct DiffLineView: View {
    let line: DiffLine
    let isSelected: Bool

    var backgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.25)
        }
        switch line.type {
        case .added:
            return Color.green.opacity(0.12)
        case .removed:
            return Color.red.opacity(0.12)
        case .context:
            return Color.clear
        case .header:
            return Color.clear
        }
    }

    var textColor: Color {
        switch line.type {
        case .added:
            return Color.green.opacity(0.9)
        case .removed:
            return Color.red.opacity(0.9)
        case .context:
            return .primary
        case .header:
            return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Old line number
            Text(line.oldLineNumber.map(String.init) ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)

            // New line number
            Text(line.newLineNumber.map(String.init) ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)

            // Content
            Text(line.text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(backgroundColor)
    }
}
