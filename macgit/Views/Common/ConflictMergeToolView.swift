//
//  ConflictMergeToolView.swift
//  macgit
//

import SwiftUI

struct ConflictMergeToolView: View {
    let allConflictFiles: [StatusFile]
    let repositoryURL: URL
    let onResolved: () -> Void
    let onClose: () -> Void

    @State private var selectedFile: StatusFile
    @State private var document: ConflictResolutionDocument?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var selectedConflictIndex = 0
    @State private var hasUnsavedChanges = false

    init(allConflictFiles: [StatusFile], repositoryURL: URL, onResolved: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.allConflictFiles = allConflictFiles
        self.repositoryURL = repositoryURL
        self.onResolved = onResolved
        self.onClose = onClose
        self._selectedFile = State(initialValue: allConflictFiles.first!)
    }

    var body: some View {
        ZStack {
            rootView
        }
        .frame(minWidth: 900, minHeight: 600)
        .navigationTitle("")
        .toolbar { toolbarContent }
        .task {
            await loadDocument(for: selectedFile)
        }
        .alert("Error", isPresented: $showingError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "An unknown error occurred")
        })
        .onChange(of: selectedFile) { _, newFile in
            if hasUnsavedChanges {
                // In a real app, show confirmation here. For now, just proceed.
            }
            Task {
                await loadDocument(for: newFile)
            }
        }
    }

    // MARK: - Root

    @ViewBuilder
    private var rootView: some View {
        NavigationSplitView {
            sidebarPane
        } detail: {
            detailPane
        }
    }

    // MARK: - Sidebar

    private var sidebarPane: some View {
        List(selection: $selectedFile) {
            ForEach(allConflictFiles) { file in
                Label(file.displayName, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.purple)
                    .tag(file)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        VStack(spacing: 0) {
            Color(nsColor: .controlBackgroundColor)
                .frame(height: 1)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.separator)
                        .frame(height: 0.5)
                }

            if isLoading {
                ProgressView("Loading conflict details…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let document = document {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(document.sections.enumerated()), id: \.offset) { index, section in
                            if section.isConflict {
                                conflictBlockView(section: section, sectionIndex: index, document: document)
                            } else {
                                contextBlockView(text: section.contextText)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            } else {
                EmptyStateView(
                    icon: "arrow.triangle.merge",
                    message: "No text conflicts found",
                    detail: "This file could not be loaded into the merge tool."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            if let document = document {
                HStack(spacing: 0) {
                    Button {
                        navigateToPreviousConflict(in: document)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 22)
                    }
                    // .buttonStyle(.plain)
                    .disabled(selectedConflictIndex == 0)
                    .accessibilityLabel("Previous conflict")

                    Divider()
                        .frame(height: 12)

                    Button {
                        navigateToNextConflict(in: document)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 22)
                    }
                    // .buttonStyle(.plain)
                    .disabled(selectedConflictIndex >= document.conflictCount - 1)
                    .accessibilityLabel("Next conflict")
                }
                .background(
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    Capsule()
                        .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
                )
            }
        }

        ToolbarItem(placement: .principal) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Resolve Conflicts")
                        .font(.headline.weight(.semibold))
                    Text(selectedFile.path)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let document = document {
                    let conflictCount = document.conflictCount
                    let remaining = conflictCount - resolvedCount(in: document)
                    Text("Conflict \(selectedConflictIndex + 1) of \(conflictCount) — \(remaining) remaining")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }

        ToolbarItem(placement: .confirmationAction) {
            Button {
                Task {
                    await saveAndAdvance()
                }
            } label: {
                Text(isSaving ? "Resolving…" : "Merge")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.accentColor)
                    )
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.plain)
            .disabled(isSaving)
        }
    }

    // MARK: - Conflict Block

    private func conflictBlockView(section: ConflictResolutionSection, sectionIndex: Int, document: ConflictResolutionDocument) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                HStack(spacing: 16) {
                    Toggle("Current", isOn: Binding(
                        get: { section.resolution == .current || section.resolution == .both },
                        set: { isOn in
                            applyCheckbox(isCurrent: true, isOn: isOn, to: sectionIndex)
                        }
                    ))
                    .toggleStyle(.checkbox)

                    Toggle("Incoming", isOn: Binding(
                        get: { section.resolution == .incoming || section.resolution == .both },
                        set: { isOn in
                            applyCheckbox(isCurrent: false, isOn: isOn, to: sectionIndex)
                        }
                    ))
                    .toggleStyle(.checkbox)
                }

                Spacer()

                Text("Conflict Block")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.purple.opacity(0.04))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.separator.opacity(0.5))
                    .frame(height: 0.5)
            }

            // Panes
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    codePane(title: "Current", text: section.currentText, isReadOnly: true)
                    Divider()
                    codePane(title: "Incoming", text: section.incomingText, isReadOnly: true)
                }
                .frame(minHeight: 120)

                Divider()

                resultPane(section: section, sectionIndex: sectionIndex)
                    .frame(minHeight: 120)
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
        .id(section.id)
    }

    // MARK: - Context Block

    private func contextBlockView(text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            CodeBlockView(text: text, fileExtension: selectedFile.fileExtension)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Code Pane

    private func codePane(title: String, text: String, isReadOnly: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.secondary.opacity(0.04))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.separator.opacity(0.5))
                    .frame(height: 0.5)
            }

            ScrollView(.horizontal) {
                CodeBlockView(text: text, fileExtension: selectedFile.fileExtension)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Result Pane

    private func resultPane(section: ConflictResolutionSection, sectionIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Result")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.secondary.opacity(0.04))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.separator.opacity(0.5))
                    .frame(height: 0.5)
            }

            ScrollView(.horizontal) {
                CodeEditorView(
                    text: resultBinding(for: sectionIndex),
                    fileExtension: selectedFile.fileExtension
                )
                .frame(minHeight: 100)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Helpers

    private func applyCheckbox(isCurrent: Bool, isOn: Bool, to sectionIndex: Int) {
        guard var document = document else { return }
        let section = document.sections[sectionIndex]
        let currentOn = isCurrent ? isOn : (section.resolution == .current || section.resolution == .both)
        let incomingOn = !isCurrent ? isOn : (section.resolution == .incoming || section.resolution == .both)

        if currentOn && incomingOn {
            document.sections[sectionIndex].resolution = .both
            document.sections[sectionIndex].manualResult = ""
        } else if currentOn {
            document.sections[sectionIndex].resolution = .current
            document.sections[sectionIndex].manualResult = ""
        } else if incomingOn {
            document.sections[sectionIndex].resolution = .incoming
            document.sections[sectionIndex].manualResult = ""
        } else {
            document.sections[sectionIndex].resolution = .manual
            document.sections[sectionIndex].manualResult = ""
        }

        self.document = document
        hasUnsavedChanges = true
    }

    private func resultBinding(for sectionIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard let document = document else { return "" }
                return document.sections[sectionIndex].editorText
            },
            set: { newValue in
                guard var document = document else { return }
                document.sections[sectionIndex].resolution = .manual
                document.sections[sectionIndex].manualResult = newValue
                self.document = document
                hasUnsavedChanges = true
            }
        )
    }

    private func resolvedCount(in document: ConflictResolutionDocument) -> Int {
        document.sections.filter { $0.isConflict && $0.resolution != .manual }.count
    }

    private func navigateToPreviousConflict(in document: ConflictResolutionDocument) {
        let conflictIndices = document.sections.indices.filter { document.sections[$0].isConflict }
        guard let currentIndex = conflictIndices.firstIndex(of: selectedConflictIndex) else { return }
        let prevIndex = max(0, currentIndex - 1)
        selectedConflictIndex = conflictIndices[prevIndex]
    }

    private func navigateToNextConflict(in document: ConflictResolutionDocument) {
        let conflictIndices = document.sections.indices.filter { document.sections[$0].isConflict }
        guard let currentIndex = conflictIndices.firstIndex(of: selectedConflictIndex) else { return }
        let nextIndex = min(conflictIndices.count - 1, currentIndex + 1)
        selectedConflictIndex = conflictIndices[nextIndex]
    }

    private func loadDocument(for file: StatusFile) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loadedDocument = try await GitStatusService.shared.conflictDocument(for: file, in: repositoryURL)
            await MainActor.run {
                document = loadedDocument
                selectedConflictIndex = 0
                hasUnsavedChanges = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func saveAndAdvance() async {
        guard let document = document else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await GitStatusService.shared.resolveConflict(file: selectedFile, in: repositoryURL, with: document)
            await MainActor.run {
                hasUnsavedChanges = false
                // Move to next file if available
                if let currentIndex = allConflictFiles.firstIndex(of: selectedFile),
                   currentIndex + 1 < allConflictFiles.count {
                    selectedFile = allConflictFiles[currentIndex + 1]
                } else {
                    onClose()
                    onResolved()
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}
