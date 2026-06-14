# Sidebar Remotes Tree Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a SourceTree-style REMOTES tree to the main sidebar and refresh it after Fetch.

**Architecture:** Reuse the existing sidebar branch tree model, but move tree construction into a small tested helper so remotes can share the same slash-delimited hierarchy. SidebarView will keep separate loading and expansion state for local branches, tags, and remotes, while MainWindowView will route remote branch selection to History with a full ref such as `origin/main`.

**Tech Stack:** Swift 5, SwiftUI, XCTest, Git CLI via `GitStatusService`.

---

### Task 1: Test Sidebar Tree Construction

**Files:**
- Create: `macgit/Views/MainWindow/SidebarTreeBuilder.swift`
- Create: `macgitTests/SidebarTreeBuilderTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `macgitTests/SidebarTreeBuilderTests.swift` with:

```swift
import XCTest
@testable import macgit

final class SidebarTreeBuilderTests: XCTestCase {
    func testBuildTreeGroupsSlashDelimitedRefs() {
        let nodes = SidebarTreeBuilder.buildTree(from: [
            "main",
            "feature/login",
            "feature/sidebar/remotes"
        ])

        XCTAssertEqual(nodes.map(\.name), ["feature", "main"])
        XCTAssertTrue(nodes[0].isFolder)
        XCTAssertEqual(nodes[0].children.map(\.name), ["login", "sidebar"])
        XCTAssertEqual(nodes[0].children[1].children.map(\.fullPath), ["feature/sidebar/remotes"])
    }

    func testRemoteTreeUsesRemoteAsTopLevelFolderAndNormalizesHead() {
        let nodes = SidebarTreeBuilder.buildRemoteTree(remoteBranchesByRemote: [
            "origin": ["HEAD -> origin/main", "main", "feature/api"],
            "upstream": ["develop"]
        ])

        XCTAssertEqual(nodes.map(\.name), ["origin", "upstream"])
        XCTAssertEqual(nodes[0].fullPath, "origin")
        XCTAssertTrue(nodes[0].isFolder)
        XCTAssertEqual(nodes[0].children.map(\.name), ["feature", "HEAD", "main"])
        XCTAssertEqual(nodes[0].children.first { $0.name == "HEAD" }?.fullPath, "origin/HEAD")
        XCTAssertEqual(nodes[0].children.first { $0.name == "main" }?.fullPath, "origin/main")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/SidebarTreeBuilderTests
```

Expected: FAIL because `SidebarTreeBuilder` does not exist yet.

- [ ] **Step 3: Add minimal implementation**

Create `macgit/Views/MainWindow/SidebarTreeBuilder.swift` with:

```swift
import Foundation

struct SidebarTreeBuilder {
    static func buildTree(from refs: [String], prefix: String = "") -> [BranchNode] {
        var groups = [String: [String]]()
        var leaves = Set<String>()

        for ref in refs {
            let relative = prefix.isEmpty ? ref : String(ref.dropFirst(prefix.count + 1))
            if let slashIndex = relative.firstIndex(of: "/") {
                let first = String(relative[..<slashIndex])
                let rest = String(relative[relative.index(after: slashIndex)...])
                let childRef = prefix.isEmpty ? ref : "\(prefix)/\(rest)"
                groups[first, default: []].append(childRef)
            } else {
                leaves.insert(relative)
            }
        }

        var nodes: [BranchNode] = []

        for (name, childRefs) in groups.sorted(by: { $0.key < $1.key }) {
            let fullPath = prefix.isEmpty ? name : "\(prefix)/\(name)"
            var children = buildTree(from: childRefs, prefix: fullPath)
            if leaves.remove(name) != nil {
                children.insert(
                    BranchNode(name: name, fullPath: fullPath, isFolder: false, children: []),
                    at: 0
                )
            }
            nodes.append(BranchNode(name: name, fullPath: fullPath, isFolder: true, children: children))
        }

        for leaf in leaves.sorted() {
            let fullPath = prefix.isEmpty ? leaf : "\(prefix)/\(leaf)"
            nodes.append(BranchNode(name: leaf, fullPath: fullPath, isFolder: false, children: []))
        }

        return nodes
    }

    static func buildRemoteTree(remoteBranchesByRemote: [String: [String]]) -> [BranchNode] {
        remoteBranchesByRemote.keys.sorted().map { remote in
            let branchRefs = remoteBranchesByRemote[remote, default: []]
                .map(normalizedRemoteBranchName)
                .filter { !$0.isEmpty }
                .map { "\(remote)/\($0)" }
            return BranchNode(
                name: remote,
                fullPath: remote,
                isFolder: true,
                children: buildTree(from: branchRefs, prefix: remote)
            )
        }
    }

    private static func normalizedRemoteBranchName(_ branch: String) -> String {
        let trimmed = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("HEAD -> ") {
            return "HEAD"
        }
        return trimmed
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/SidebarTreeBuilderTests
```

Expected: PASS.

### Task 2: Render REMOTES In Sidebar

**Files:**
- Modify: `macgit/Views/MainWindow/SidebarView.swift`
- Modify: `macgit/Views/MainWindow/MainWindowView.swift`

- [ ] **Step 1: Add remote selection state**

Update `SidebarSelection` in `SidebarView.swift`:

```swift
enum SidebarSelection: Hashable {
    case item(SidebarItem)
    case branch(String)
    case tag(String)
    case remoteBranch(String)
}
```

- [ ] **Step 2: Add REMOTES state to SidebarView**

Add these `@State` properties beside the existing tag state:

```swift
@State private var remoteNodes: [BranchNode] = []
@State private var isLoadingRemotes = false
@State private var expandedRemoteFolders: Set<String> = []
```

- [ ] **Step 3: Replace the REMOTES placeholder section**

Replace the placeholder loop with a real REMOTES section followed by the remaining placeholder sections:

```swift
// REMOTES section
Section {
    if sectionStates.remotesExpanded {
        if isLoadingRemotes && remoteNodes.isEmpty {
            ProgressView()
                .scaleEffect(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
        } else if remoteNodes.isEmpty {
            Text("No remotes")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(visibleRemoteRows) { row in
                remoteRowView(for: row)
            }
        }
    }
} header: {
    sectionHeader(SidebarSection.remotes, isExpanded: sectionStates.remotesExpanded)
}

ForEach([SidebarSection.stashes, .submodules, .subtrees], id: \.self) { section in
    Section(section.rawValue) {
        Text("Coming soon")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .disabled(true)
}
```

- [ ] **Step 4: Add visible remote row flattening**

Add beside `visibleTagRows`:

```swift
private var visibleRemoteRows: [BranchRowItem] {
    var rows: [BranchRowItem] = []
    func traverse(_ nodes: [BranchNode], indent: Int) {
        for node in nodes {
            rows.append(BranchRowItem(
                id: node.id,
                name: node.name,
                fullPath: node.fullPath,
                isFolder: node.isFolder,
                indent: indent
            ))
            if node.isFolder && expandedRemoteFolders.contains(node.fullPath) {
                traverse(node.children, indent: indent + 1)
            }
        }
    }
    traverse(remoteNodes, indent: 0)
    return rows
}
```

- [ ] **Step 5: Add remote row rendering**

Add beside `tagRowView`:

```swift
@ViewBuilder
private func remoteRowView(for row: BranchRowItem) -> some View {
    let baseView = HStack(spacing: 4) {
        HStack(spacing: 0) {
            ForEach(0..<row.indent, id: \.self) { _ in
                Color.clear.frame(width: 16)
            }
        }

        if row.isFolder {
            Image(systemName: expandedRemoteFolders.contains(row.fullPath) ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .center)
        } else {
            Color.clear.frame(width: 16)
        }

        Text(row.name)
            .font(.system(size: 12))
            .lineLimit(1)
    }
    .padding(.vertical, 2)
    .contentShape(Rectangle())

    if row.isFolder {
        baseView.onTapGesture {
            toggleRemoteFolder(row.fullPath)
        }
    } else {
        baseView
            .tag(SidebarSelection.remoteBranch(row.fullPath))
            .onTapGesture {
                selection = .remoteBranch(row.fullPath)
            }
            .contextMenu {
                Button("Copy Branch Name to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(row.fullPath, forType: .string)
                }
            }
    }
}
```

- [ ] **Step 6: Add remote loading and refresh hooks**

Call `await loadRemotes()` in `.task` and `.onReceive(.repositoryDidChange)`, then add:

```swift
private func toggleRemoteFolder(_ path: String) {
    if expandedRemoteFolders.contains(path) {
        expandedRemoteFolders.remove(path)
    } else {
        expandedRemoteFolders.insert(path)
    }
}

private func loadRemotes() async {
    isLoadingRemotes = true
    defer { isLoadingRemotes = false }
    let remotes = await GitStatusService.shared.remotes(in: repositoryURL)
    var branchesByRemote: [String: [String]] = [:]
    for remote in remotes {
        branchesByRemote[remote] = await GitStatusService.shared.remoteBranches(remote: remote, in: repositoryURL)
    }
    let tree = SidebarTreeBuilder.buildRemoteTree(remoteBranchesByRemote: branchesByRemote)
    let allFolders = collectFolderPaths(from: tree)
    await MainActor.run {
        remoteNodes = tree
        if expandedRemoteFolders.isEmpty {
            expandedRemoteFolders = allFolders
        }
    }
}
```

- [ ] **Step 7: Route remote branch selection in MainWindowView**

Update the detail switch and selection change handling:

```swift
case .item(.history), .branch, .tag, .remoteBranch:
    HistoryView(repositoryURL: repositoryURL, selectedBranch: selectedBranchName)
```

```swift
} else if case .remoteBranch(let name) = newItem {
    selectedBranchName = name
} else {
    selectedBranchName = nil
}
```

### Task 3: Replace Duplicated Tree Builder Calls

**Files:**
- Modify: `macgit/Views/MainWindow/SidebarView.swift`

- [ ] **Step 1: Use `SidebarTreeBuilder` for local branches and tags**

Replace:

```swift
let tree = buildBranchTree(from: locals)
```

with:

```swift
let tree = SidebarTreeBuilder.buildTree(from: locals)
```

Replace:

```swift
let tree = buildBranchTree(from: tags)
```

with:

```swift
let tree = SidebarTreeBuilder.buildTree(from: tags)
```

- [ ] **Step 2: Delete the old private `buildBranchTree` method**

Remove the private method from `SidebarView.swift`; keep `collectFolderPaths(from:)` because SidebarView still owns expansion state.

- [ ] **Step 3: Run targeted tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/SidebarTreeBuilderTests
```

Expected: PASS.

### Task 4: Validate Feature

**Files:**
- Validate: `openspec/changes/add-sidebar-remotes-tree/`
- Build/Test: project root

- [ ] **Step 1: Validate OpenSpec**

Run:

```bash
openspec validate add-sidebar-remotes-tree --strict
```

Expected: PASS.

- [ ] **Step 2: Run full tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: PASS.

- [ ] **Step 3: Run app build**

Run:

```bash
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.
