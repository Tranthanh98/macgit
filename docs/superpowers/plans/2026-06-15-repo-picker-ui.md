# Repo Picker UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the repo picker so each recent repo shows its current branch and moved/deleted state, while adding search and sort controls with default sorting by last opened.

**Architecture:** Keep the change concentrated in `RepoPickerView.swift`. Add a lightweight in-view model for repo metadata so branch and repository health can be fetched asynchronously per row without changing the persistence model. Drive search and sort from local view state, and keep the existing recent-repository list scrollable by preserving a bounded-height scrolling container.

**Tech Stack:** SwiftUI, `GitStatusService`, `RecentRepositoriesStore`, AppKit file existence checks

---

### Task 1: Add repo row state and filtering/sorting inputs

**Files:**
- Modify: `/Users/thanhtran/Project/macgit/macgit/Views/MainWindow/RepoPickerView.swift`

- [ ] **Step 1: Add a row metadata model and sort enum**

```swift
private struct RepoPickerRowState {
    var currentBranch: String?
    var isMissing: Bool
    var isLoading: Bool
}

private enum RepoPickerSortOption: String, CaseIterable, Identifiable {
    case lastOpened = "Last Opened"
    case name = "Name"

    var id: String { rawValue }
}
```

- [ ] **Step 2: Add state for search, sort, and loaded row metadata**

```swift
@State private var searchText = ""
@State private var sortOption: RepoPickerSortOption = .lastOpened
@State private var rowStates: [URL: RepoPickerRowState] = [:]
```

- [ ] **Step 3: Add filtered/sorted repo helpers**

```swift
private var visibleRepositories: [RecentRepository] {
    let filtered = store.repositories.filter { repo in
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let haystack = [
            repo.name,
            repo.url.path,
            rowStates[repo.url]?.currentBranch ?? ""
        ].joined(separator: " ").lowercased()
        return haystack.contains(query.lowercased())
    }

    switch sortOption {
    case .lastOpened:
        return filtered.sorted { $0.lastOpened > $1.lastOpened }
    case .name:
        return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
```

- [ ] **Step 4: Add a row loader that fills in branch and missing-repo state**

```swift
private func loadRowState(for repo: RecentRepository) async {
    let exists = FileManager.default.fileExists(atPath: repo.url.path)
    guard exists else {
        await MainActor.run {
            rowStates[repo.url] = RepoPickerRowState(currentBranch: nil, isMissing: true, isLoading: false)
        }
        return
    }

    let branch = await GitStatusService.shared.currentBranch(in: repo.url)
    await MainActor.run {
        rowStates[repo.url] = RepoPickerRowState(currentBranch: branch, isMissing: false, isLoading: false)
    }
}
```

- [ ] **Step 5: Run a focused build to confirm the new state compiles**

Run:

```bash
xcodebuild -project /Users/thanhtran/Project/macgit/macgit.xcodeproj -scheme macgit -configuration Debug -destination 'platform=macOS' build
```

Expected: build succeeds with no SwiftUI type errors.

### Task 2: Rework the picker layout to match the SourceTree-inspired UI

**Files:**
- Modify: `/Users/thanhtran/Project/macgit/macgit/Views/MainWindow/RepoPickerView.swift`

- [ ] **Step 1: Replace the centered layout with a top toolbar and a repo panel**

```swift
VStack(spacing: 18) {
    headerSection
    controlBar
    recentRepositoriesSection
}
.padding(24)
```

- [ ] **Step 2: Add a search field and sort menu**

```swift
HStack(spacing: 12) {
    TextField("Filter repositories", text: $searchText)
        .textFieldStyle(.roundedBorder)
    Menu {
        Picker("Sort", selection: $sortOption) {
            ForEach(RepoPickerSortOption.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
    } label: {
        Image(systemName: "arrow.up.arrow.down")
    }
}
```

- [ ] **Step 3: Render each row with repo name, current branch pill, and moved/deleted badge**

```swift
HStack(spacing: 12) {
    Image(systemName: "chevron.left.forwardslash.chevron.right")
    VStack(alignment: .leading, spacing: 2) {
        Text(repo.name)
        Text(repo.url.path)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
    Spacer()
    if let branch = rowStates[repo.url]?.currentBranch, !branch.isEmpty {
        Text(branch)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
    } else if rowStates[repo.url]?.isMissing == true {
        Text("Repository moved or deleted")
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange, in: Capsule())
    }
}
```

- [ ] **Step 4: Keep the recent repo list scrollable with a bounded-height container**

```swift
ScrollView {
    LazyVStack(spacing: 0) {
        ForEach(visibleRepositories) { repo in
            repoRow(repo)
            Divider()
        }
    }
}
.frame(maxHeight: 320)
```

- [ ] **Step 5: Run the app and visually verify the picker on a long recent-repo list**

Run:

```bash
xcodebuild -project /Users/thanhtran/Project/macgit/macgit.xcodeproj -scheme macgit -configuration Debug -destination 'platform=macOS' build
```

Expected: the picker shows search, sort, branch pills, and the missing-repo badge without clipped rows.

### Task 3: Wire actions and polish empty/loading states

**Files:**
- Modify: `/Users/thanhtran/Project/macgit/macgit/Views/MainWindow/RepoPickerView.swift`

- [ ] **Step 1: Keep open/add actions working for filtered rows**

```swift
Button(action: {
    store.add(repo.url)
    onRepositoryOpened(repo.url)
}) {
    repoRowContent(repo)
}
```

- [ ] **Step 2: Show a helpful empty state when search removes all rows**

```swift
if visibleRepositories.isEmpty {
    ContentUnavailableView(
        "No Repositories Found",
        systemImage: "magnifyingglass",
        description: Text("Try a different search or clear the filter.")
    )
}
```

- [ ] **Step 3: Verify the final build again**

Run:

```bash
xcodebuild -project /Users/thanhtran/Project/macgit/macgit.xcodeproj -scheme macgit -configuration Debug -destination 'platform=macOS' build
```

Expected: build succeeds, picker opens, search/sort work, and recent list still scrolls normally.

