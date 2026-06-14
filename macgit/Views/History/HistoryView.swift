//
//  HistoryView.swift
//  macgit
//

import SwiftUI

struct HistoryView: View {
    let repositoryURL: URL
    let selectedBranch: String?
    private static let historyPageSize = 120
    private static let historyScrollSpaceName = "historyScroll"
    
    @State private var commits: [Commit] = []
    @State private var graphLayout: CommitGraphLayout? = nil
    @State private var selectedCommit: Commit? = nil
    @State private var fileChanges: [CommitFileChange] = []
    @State private var selectedFile: CommitFileChange? = nil
    @State private var diffHunks: [DiffHunk] = []
    @State private var showAllBranches = true
    @AppStorage("history.messageWidth") private var messageColumnWidth: Double = 200
    @AppStorage("history.authorWidth") private var authorColumnWidth: Double = 120
    @AppStorage("history.dateWidth") private var dateColumnWidth: Double = 80
    @AppStorage("history.commitWidth") private var commitColumnWidth: Double = 70
    @State private var isLoading = false
    @State private var isRefreshingHistory = false
    @State private var refreshIndicatorTask: Task<Void, Never>? = nil
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var scrollTarget: String? = nil
    @State private var rowFrames: [String: CGRect] = [:]
    @State private var paging = HistoryPagingState(pageSize: HistoryView.historyPageSize)
    
    init(repositoryURL: URL, selectedBranch: String? = nil) {
        self.repositoryURL = repositoryURL
        self.selectedBranch = selectedBranch
        self._showAllBranches = State(initialValue: selectedBranch == nil)
        self._paging = State(initialValue: HistoryPagingState(pageSize: Self.historyPageSize))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            BranchFilterBar(
                showAllBranches: $showAllBranches
            ) {}
            
            if isLoading && commits.isEmpty {
                ProgressView("Loading history…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if commits.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    message: "No commits to display",
                    detail: "Repository may be empty"
                )
            } else {
                ZStack(alignment: .top) {
                    PersistentVSplit(
                        autosaveName: "HistoryMainSplit",
                        top: { commitGraphList.frame(minHeight: 200) },
                        bottom: { commitDetailPanel.frame(minHeight: 180) }
                    )

                    if isRefreshingHistory {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Loading branch history…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 8)
                    }
                }
            }
        }
        .id("history")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: selectedCommit) { _, newCommit in
            Task {
                await loadFileChanges(for: newCommit)
            }
        }
        .onChange(of: selectedFile) { _, newFile in
            Task {
                await loadDiff(for: newFile, in: selectedCommit)
            }
        }
        .task(id: historyLoadKey) {
            await loadHistory(reset: true)
        }
        .alert("Error", isPresented: $showingError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "An unknown error occurred")
        })
    }
    
    // MARK: - Top Panel
    
    private var graphWidth: CGFloat {
        let maxLane = graphLayout?.laneCount ?? 1
        return CGFloat(maxLane) * 14 + 8
    }

    private func commitListHeader(messageWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: graphWidth, height: 16)
                .fixedSize()

            Text("Message")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .frame(width: messageWidth, alignment: .leading)

            ColumnResizer(
                leftWidth: Binding(
                    get: { CGFloat(messageColumnWidth) },
                    set: { messageColumnWidth = Double($0) }
                ),
                rightWidth: Binding(
                    get: { CGFloat(authorColumnWidth) },
                    set: { authorColumnWidth = Double($0) }
                )
            )

            Text("Author")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .frame(width: CGFloat(authorColumnWidth), alignment: .leading)

            ColumnResizer(
                leftWidth: Binding(
                    get: { CGFloat(authorColumnWidth) },
                    set: { authorColumnWidth = Double($0) }
                ),
                rightWidth: Binding(
                    get: { CGFloat(dateColumnWidth) },
                    set: { dateColumnWidth = Double($0) }
                )
            )

            Text("Date")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .frame(width: CGFloat(dateColumnWidth), alignment: .trailing)

            ColumnResizer(
                leftWidth: Binding(
                    get: { CGFloat(dateColumnWidth) },
                    set: { dateColumnWidth = Double($0) }
                ),
                rightWidth: Binding(
                    get: { CGFloat(commitColumnWidth) },
                    set: { commitColumnWidth = Double($0) }
                )
            )

            Text("Commit")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .frame(width: CGFloat(commitColumnWidth), alignment: .trailing)

            ColumnResizer(
                leftWidth: Binding(
                    get: { CGFloat(commitColumnWidth) },
                    set: { commitColumnWidth = Double($0) }
                ),
                rightWidth: Binding(
                    get: { CGFloat(0) },
                    set: { _ in }
                )
            )
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .frame(height: 20)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 0.5)
        }
    }

    private var commitGraphList: some View {
        GeometryReader { geometry in
            let viewportWidth = geometry.size.width
            let resizers: CGFloat = 4 * 6
            let padding: CGFloat = 8 + 16
            let fixedWidth = graphWidth + CGFloat(messageColumnWidth) + CGFloat(authorColumnWidth) + CGFloat(dateColumnWidth) + CGFloat(commitColumnWidth) + resizers + padding
            let extraSpace = max(0, viewportWidth - fixedWidth)
            let effectiveMessageWidth = CGFloat(messageColumnWidth) + extraSpace

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    commitListHeader(messageWidth: effectiveMessageWidth)

                    ScrollViewReader { proxy in
                        ScrollView(.vertical) {
                            ZStack(alignment: .topLeading) {
                                // Graph lines
                                if let layout = graphLayout {
                                    BranchGraphCanvas(
                                        nodes: layout.nodes,
                                        edges: layout.edges,
                                        laneCount: layout.laneCount
                                    )
                                    .padding(.leading, 4)
                                }

                                // Commit rows overlay
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    if let layout = graphLayout {
                                        ForEach(Array(layout.nodes.enumerated()), id: \.element.id) { index, node in
                                            CommitRowView(
                                                node: node,
                                                graphWidth: graphWidth,
                                                isSelected: selectedCommit?.hash == node.commit.hash,
                                                messageWidth: effectiveMessageWidth,
                                                authorWidth: CGFloat(authorColumnWidth),
                                                dateWidth: CGFloat(dateColumnWidth),
                                                commitWidth: CGFloat(commitColumnWidth)
                                            )
                                            .id(node.commit.hash)
                                            .background(
                                                GeometryReader { geo in
                                                    Color.clear.preference(
                                                        key: CommitRowFramePreferenceKey.self,
                                                        value: [node.commit.hash: geo.frame(in: .named(Self.historyScrollSpaceName))]
                                                    )
                                                }
                                            )
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedCommit = node.commit
                                            }
                                            .onAppear {
                                                if index == layout.nodes.count - 1 {
                                                    Task {
                                                        await loadOlderHistoryIfNeeded()
                                                    }
                                                }
                                            }
                                            .contextMenu {
                                                commitContextMenu(for: node.commit)
                                            }
                                        }
                                    }
                                    if paging.isLoadingMore {
                                        HStack {
                                            Spacer()
                                            ProgressView("Loading older commits…")
                                                .font(.caption)
                                                .padding(.vertical, 12)
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.leading, 4)
                            }
                        }
                        .coordinateSpace(name: Self.historyScrollSpaceName)
                        .onPreferenceChange(CommitRowFramePreferenceKey.self) { frames in
                            rowFrames = frames
                        }
                        .task(id: scrollTarget) {
                            guard let target = scrollTarget else { return }
                            let viewportHeight = max(0, geometry.size.height - 20)
                            var attempts = 0
                            while rowFrames[target] == nil, attempts < 5 {
                                attempts += 1
                                await Task.yield()
                            }
                            if Self.shouldAutoCenterCommit(
                                targetHash: target,
                                rowFrames: rowFrames,
                                viewportHeight: viewportHeight
                            ) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(target, anchor: .center)
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: viewportWidth)
            }
        }
        .id(showAllBranches)
    }
    
    // MARK: - Bottom Panel
    
    private var commitDetailPanel: some View {
        Group {
            if let commit = selectedCommit {
                VStack(spacing: 0) {
                    // Commit info header
                    commitInfoHeader(for: commit)
                    
                    PersistentHSplit(
                        autosaveName: "HistoryDetailSplit",
                        left: {
                            CommitFileListView(changes: fileChanges, selectedFile: $selectedFile)
                                .frame(minWidth: 220)
                        },
                        right: {
                            commitDiffViewer
                                .frame(minWidth: 300)
                        }
                    )
                }
            } else {
                EmptyStateView(
                    icon: "doc.text",
                    message: "Select a commit",
                    detail: "Click a commit above to see its changes"
                )
            }
        }
    }
    
    private func commitInfoHeader(for commit: Commit) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(commit.message)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(commit.author)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text(commit.hash)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            if !commit.refs.isEmpty {
                HStack(spacing: 4) {
                    ForEach(commit.refs.prefix(5), id: \.self) { ref in
                        RefLabel(text: ref)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 0.5)
        }
    }
    
    private var commitDiffViewer: some View {
        Group {
            if let file = selectedFile {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.primary)
                            .font(.system(size: 14, weight: .medium))
                        Text(file.path)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(.separator)
                            .frame(height: 0.5)
                    }
                    
                    DiffView(
                        hunks: diffHunks,
                        file: nil,
                        repositoryURL: nil,
                        onRefresh: {},
                        onError: { _ in }
                    )
                }
            } else {
                EmptyStateView(
                    icon: "doc.text",
                    message: "Select a file",
                    detail: "Click a file on the left to see its diff"
                )
            }
        }
    }
    
    // MARK: - Context Menu
    
    private func commitContextMenu(for commit: Commit) -> some View {
        Group {
            Button("Checkout Commit") {
                Task { await checkoutCommit(commit) }
            }
            Button("Cherry Pick") {
                Task { await cherryPickCommit(commit) }
            }
            Divider()
            Button("Copy Hash") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commit.hash, forType: .string)
            }
            Button("Copy Message") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commit.message, forType: .string)
            }
        }
    }
    
    // MARK: - Data Loading

    private func loadHistory(reset: Bool) async {
        isLoading = true
        defer { isLoading = false }
        if reset {
            await MainActor.run {
                paging.reset()
                scrollTarget = nil
                rowFrames = [:]
                cancelHistoryRefreshIndicator()
                if commits.isEmpty {
                    graphLayout = nil
                    selectedCommit = nil
                    fileChanges = []
                    selectedFile = nil
                    diffHunks = []
                } else {
                    scheduleHistoryRefreshIndicator()
                }
            }
        }
        let scope = Self.historyScope(selectedBranch: selectedBranch, showAllBranches: showAllBranches)
        let skip = await MainActor.run { paging.loadedCount }
        let newCommits: [Commit]
        switch scope {
        case .allBranches:
            newCommits = await GitStatusService.shared.commitHistory(
                allBranches: true,
                limit: Self.historyPageSize,
                skip: skip,
                in: repositoryURL
            )
        case .currentBranch:
            newCommits = await GitStatusService.shared.commitHistory(
                allBranches: false,
                limit: Self.historyPageSize,
                skip: skip,
                in: repositoryURL
            )
        case .ref(let ref):
            newCommits = await GitStatusService.shared.commitHistory(
                branch: ref,
                limit: Self.historyPageSize,
                skip: skip,
                in: repositoryURL
            )
        }

        let newSelectedCommit: Commit?
        let newScrollTarget: String?
        switch scope {
        case .ref:
            newSelectedCommit = newCommits.first
            newScrollTarget = newCommits.first?.hash
        case .allBranches:
            if let selectedBranch,
               let tipHash = await GitStatusService.shared.tipHash(for: selectedBranch, in: repositoryURL),
               let tipCommit = newCommits.first(where: { $0.hash == tipHash }) {
                newSelectedCommit = tipCommit
                newScrollTarget = tipCommit.hash
            } else {
                newSelectedCommit = newCommits.first
                newScrollTarget = newCommits.first?.hash
            }
        case .currentBranch:
            newSelectedCommit = newCommits.first
            newScrollTarget = newCommits.first?.hash
        }

        await MainActor.run {
            if reset || skip == 0 {
                commits = newCommits
            } else {
                commits.append(contentsOf: newCommits)
            }
            graphLayout = CommitGraphLayoutEngine.layout(commits: commits)
            if let newSelectedCommit {
                selectedCommit = newSelectedCommit
                if skip == 0 {
                    scrollTarget = newScrollTarget
                }
            }
            paging.finishLoadingMore(loaded: newCommits.count)
            cancelHistoryRefreshIndicator()
        }
    }

    private func loadOlderHistoryIfNeeded() async {
        let shouldLoad = await MainActor.run {
            guard !isLoading else { return false }
            return paging.beginLoadingMore()
        }
        guard shouldLoad else { return }
        await loadHistory(reset: false)
    }
    
    private func loadFileChanges(for commit: Commit?) async {
        guard let commit = commit else {
            await MainActor.run {
                fileChanges = []
                selectedFile = nil
                diffHunks = []
            }
            return
        }
        let changes = await GitStatusService.shared.changedFiles(
            in: commit.hash,
            in: repositoryURL
        )
        await MainActor.run {
            fileChanges = changes
            selectedFile = changes.first
        }
    }
    
    private func loadDiff(for file: CommitFileChange?, in commit: Commit?) async {
        guard let file = file, let commit = commit else {
            await MainActor.run {
                diffHunks = []
            }
            return
        }
        let hunks = await GitStatusService.shared.diff(
            for: file.path,
            in: commit.hash,
            in: repositoryURL
        )
        await MainActor.run {
            diffHunks = hunks
        }
    }
    
    private func checkoutCommit(_ commit: Commit) async {
        do {
            try await GitStatusService.shared.checkoutCommit(commit.hash, in: repositoryURL)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func cherryPickCommit(_ commit: Commit) async {
        do {
            try await GitStatusService.shared.cherryPickCommit(commit.hash, in: repositoryURL)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private var historyLoadKey: String {
        let branchKey = selectedBranch ?? "__current__"
        let scopeKey = showAllBranches ? "all" : "single"
        return "\(branchKey)|\(scopeKey)"
    }

    enum HistoryScope {
        case allBranches
        case currentBranch
        case ref(String)
    }

    static func historyScope(selectedBranch: String?, showAllBranches: Bool) -> HistoryScope {
        guard !showAllBranches else { return .allBranches }
        if let selectedBranch {
            return .ref(selectedBranch)
        }
        return .currentBranch
    }

    static func shouldAutoCenterCommit(
        targetHash: String,
        rowFrames: [String: CGRect],
        viewportHeight: CGFloat
    ) -> Bool {
        guard let frame = rowFrames[targetHash], viewportHeight > 0 else { return true }
        return !isRowVisible(frame, viewportHeight: viewportHeight)
    }

    static func isRowVisible(_ frame: CGRect, viewportHeight: CGFloat) -> Bool {
        frame.maxY > 0 && frame.minY < viewportHeight
    }

    @MainActor
    private func scheduleHistoryRefreshIndicator() {
        refreshIndicatorTask?.cancel()
        isRefreshingHistory = false
        refreshIndicatorTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if isLoading && !commits.isEmpty {
                    isRefreshingHistory = true
                }
            }
        }
    }

    @MainActor
    private func cancelHistoryRefreshIndicator() {
        refreshIndicatorTask?.cancel()
        refreshIndicatorTask = nil
        isRefreshingHistory = false
    }
}

private struct CommitRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
