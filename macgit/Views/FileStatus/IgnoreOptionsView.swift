//
//  IgnoreOptionsView.swift
//  macgit
//

import SwiftUI

struct IgnoreOptionsView: View {
    let file: StatusFile
    let repositoryURL: URL
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    enum IgnoreOption: String, CaseIterable, Identifiable {
        case exactFile
        case fileExtension
        case folder
        case customPattern

        var id: String { rawValue }

        var title: String {
            switch self {
            case .exactFile:       return "Ignore exact filename"
            case .fileExtension:   return "Ignore all files with this extension"
            case .folder:          return "Ignore everything beneath:"
            case .customPattern:   return "Ignore custom pattern"
            }
        }
    }

    @State private var selectedOption: IgnoreOption = .exactFile
    @State private var folderLevel: Int = 0
    @State private var customPattern: String = ""

    // MARK: - Derived

    private var folderOptions: [String] {
        let components = file.path.split(separator: "/").dropLast()
        guard !components.isEmpty else { return [] }
        return (0..<components.count).map { i in
            components.prefix(i + 1).joined(separator: "/")
        }
    }

    private var previewPattern: String {
        switch selectedOption {
        case .exactFile:
            return file.path
        case .fileExtension:
            return file.fileExtension.isEmpty ? file.path : "*.\(file.fileExtension)"
        case .folder:
            let options = folderOptions
            guard folderLevel >= 0 && folderLevel < options.count else { return "" }
            return "\(options[folderLevel])/"
        case .customPattern:
            return customPattern
        }
    }

    private var patternBinding: Binding<String> {
        Binding(
            get: { previewPattern },
            set: { newValue in
                if selectedOption == .customPattern {
                    customPattern = newValue
                }
            }
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ignore filename or pattern:")
                .font(.system(size: 13, weight: .semibold))
                .padding(.bottom, 8)

            TextField("", text: patternBinding)
                .textFieldStyle(.roundedBorder)
                .disabled(selectedOption != .customPattern)
                .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(IgnoreOption.allCases) { option in
                    optionRow(option)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button("OK") {
                    onConfirm(previewPattern)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedOption == .customPattern && customPattern.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440, height: 260)
        .onAppear {
            customPattern = file.path
            let options = folderOptions
            folderLevel = max(0, options.count - 1)
        }
    }

    // MARK: - Rows

    private func optionRow(_ option: IgnoreOption) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: selectedOption == option
                      ? "largecircle.fill.circle"
                      : "circle")
                    .foregroundStyle(selectedOption == option ? Color.accentColor : .secondary)
                    .font(.system(size: 13))
                    .frame(width: 16)

                Text(option.title)
                    .font(.system(size: 12))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedOption = option
            }

            Spacer()

            if option == .folder {
                folderPicker
                    .opacity(selectedOption == .folder ? 1 : 0.25)
                    .disabled(selectedOption != .folder)
            }
        }
    }

    private var folderPicker: some View {
        let options = folderOptions
        return Picker("", selection: $folderLevel) {
            ForEach(0..<options.count, id: \.self) { index in
                let components = options[index].split(separator: "/")
                let label = String(components.last ?? "")
                Text(label).tag(index)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 120)
    }
}
