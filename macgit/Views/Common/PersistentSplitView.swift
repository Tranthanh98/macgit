//
//  PersistentSplitView.swift
//  macgit
//

import SwiftUI

// MARK: - Persistent VSplit (vertical divider, top/bottom)

struct PersistentVSplit<Top: View, Bottom: View>: NSViewControllerRepresentable {
    let autosaveName: String
    @ViewBuilder let top: () -> Top
    @ViewBuilder let bottom: () -> Bottom

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var topController: NSHostingController<Top>?
        var bottomController: NSHostingController<Bottom>?
    }

    func makeNSViewController(context: Context) -> NSSplitViewController {
        let topController = NSHostingController(rootView: top())
        let bottomController = NSHostingController(rootView: bottom())

        context.coordinator.topController = topController
        context.coordinator.bottomController = bottomController

        let splitController = NSSplitViewController()
        splitController.splitView.isVertical = false
        splitController.splitView.dividerStyle = .thin
        splitController.splitView.autosaveName = autosaveName

        let topItem = NSSplitViewItem(viewController: topController)
        let bottomItem = NSSplitViewItem(viewController: bottomController)

        splitController.addSplitViewItem(topItem)
        splitController.addSplitViewItem(bottomItem)

        return splitController
    }

    func updateNSViewController(_ controller: NSSplitViewController, context: Context) {
        context.coordinator.topController?.rootView = top()
        context.coordinator.bottomController?.rootView = bottom()
    }
}

// MARK: - Persistent HSplit (horizontal divider, left/right)

struct PersistentHSplit<Left: View, Right: View>: NSViewControllerRepresentable {
    let autosaveName: String
    @ViewBuilder let left: () -> Left
    @ViewBuilder let right: () -> Right

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var leftController: NSHostingController<Left>?
        var rightController: NSHostingController<Right>?
    }

    func makeNSViewController(context: Context) -> NSSplitViewController {
        let leftController = NSHostingController(rootView: left())
        let rightController = NSHostingController(rootView: right())

        context.coordinator.leftController = leftController
        context.coordinator.rightController = rightController

        let splitController = NSSplitViewController()
        splitController.splitView.isVertical = true
        splitController.splitView.dividerStyle = .thin
        splitController.splitView.autosaveName = autosaveName

        let leftItem = NSSplitViewItem(viewController: leftController)
        let rightItem = NSSplitViewItem(viewController: rightController)

        splitController.addSplitViewItem(leftItem)
        splitController.addSplitViewItem(rightItem)

        return splitController
    }

    func updateNSViewController(_ controller: NSSplitViewController, context: Context) {
        context.coordinator.leftController?.rootView = left()
        context.coordinator.rightController?.rootView = right()
    }
}
