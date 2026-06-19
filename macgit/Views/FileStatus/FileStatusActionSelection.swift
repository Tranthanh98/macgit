import Foundation

struct FileStatusSelectionKey: Hashable {
    let path: String
    let originalPath: String?
    let isStaged: Bool

    init(file: StatusFile, isStaged: Bool) {
        self.path = file.path
        self.originalPath = file.originalPath
        self.isStaged = isStaged
    }
}

enum FileStatusSelectionSection {
    case staged
    case changed
}

enum FileStatusSelectionAction {
    case stage
    case unstage
    case discard
    case remove
}

struct FileStatusActionSelection {
    let selectedKeys: Set<FileStatusSelectionKey>
    let stagedFiles: [StatusFile]
    let changedFiles: [StatusFile]

    var selectedStagedFiles: [StatusFile] {
        selectedFiles(from: stagedFiles, isStaged: true)
    }

    var selectedChangedFiles: [StatusFile] {
        selectedFiles(from: changedFiles, isStaged: false)
    }

    var selectedFiles: [StatusFile] {
        selectedStagedFiles + selectedChangedFiles
    }

    var prunedSelection: Set<FileStatusSelectionKey> {
        selectedKeys.intersection(currentSelectionKeys)
    }

    var isSingleFileActionDisabled: Bool {
        selectedFiles.count > 1
    }

    func title(for section: FileStatusSelectionSection) -> String {
        switch section {
        case .staged:
            return selectedStagedFiles.isEmpty ? "Unstage All" : "Unstage selected"
        case .changed:
            return selectedChangedFiles.isEmpty ? "Stage All" : "Stage selected"
        }
    }

    func title(for action: FileStatusSelectionAction) -> String {
        switch action {
        case .stage:
            return isSingleFileActionDisabled && !selectedChangedFiles.isEmpty ? "Stage selected" : "Stage"
        case .unstage:
            return isSingleFileActionDisabled && !selectedStagedFiles.isEmpty ? "Unstage selected" : "Unstage"
        case .discard:
            return isSingleFileActionDisabled && !selectedChangedFiles.isEmpty ? "Discard selected" : "Discard"
        case .remove:
            return isSingleFileActionDisabled ? "Remove selected" : "Remove"
        }
    }

    func files(for action: FileStatusSelectionAction, fallback: StatusFile) -> [StatusFile] {
        switch action {
        case .stage:
            return selectedActionFiles(selectedChangedFiles, fallback: fallback)
        case .unstage:
            return selectedActionFiles(selectedStagedFiles, fallback: fallback)
        case .discard:
            return selectedActionFiles(selectedChangedFiles, fallback: fallback)
        case .remove:
            return selectedActionFiles(uniqueFilesByPath(selectedFiles), fallback: fallback)
        }
    }

    private var currentSelectionKeys: Set<FileStatusSelectionKey> {
        Set(stagedFiles.map { FileStatusSelectionKey(file: $0, isStaged: true) })
            .union(changedFiles.map { FileStatusSelectionKey(file: $0, isStaged: false) })
    }

    private func selectedFiles(from files: [StatusFile], isStaged: Bool) -> [StatusFile] {
        files.filter { selectedKeys.contains(FileStatusSelectionKey(file: $0, isStaged: isStaged)) }
    }

    private func selectedActionFiles(_ files: [StatusFile], fallback: StatusFile) -> [StatusFile] {
        if isSingleFileActionDisabled && !files.isEmpty {
            return files
        }
        return [fallback]
    }

    private func uniqueFilesByPath(_ files: [StatusFile]) -> [StatusFile] {
        var seenPaths: Set<String> = []
        return files.filter { file in
            seenPaths.insert(file.path).inserted
        }
    }
}
