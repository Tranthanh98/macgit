//
//  BranchFilterBar.swift
//  macgit
//

import SwiftUI

struct BranchFilterBar: View {
    @Binding var showAllBranches: Bool
    let onChange: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Picker("", selection: $showAllBranches) {
                Text("All Branches").tag(true)
                Text("Current Branch").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 0.5)
        }
        .onChange(of: showAllBranches) { _, _ in
            onChange()
        }
    }
}
