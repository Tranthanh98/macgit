//
//  View+ClickInteraction.swift
//  macgit
//

import AppKit
import SwiftUI

struct ClickInteractionModifier: ViewModifier {
    let onLeftClick: (NSEvent.ModifierFlags) -> Void
    let onRightClick: () -> Void
    
    func body(content: Content) -> some View {
        content.overlay(
            InteractionHostingView(
                onLeftClick: onLeftClick,
                onRightClick: onRightClick
            )
        )
    }
}

struct InteractionHostingView: NSViewRepresentable {
    let onLeftClick: (NSEvent.ModifierFlags) -> Void
    let onRightClick: () -> Void
    
    func makeNSView(context: Context) -> InteractionNSView {
        let view = InteractionNSView()
        view.onLeftClick = onLeftClick
        view.onRightClick = onRightClick
        return view
    }
    
    func updateNSView(_ nsView: InteractionNSView, context: Context) {
        nsView.onLeftClick = onLeftClick
        nsView.onRightClick = onRightClick
    }
}

class InteractionNSView: NSView {
    var onLeftClick: ((NSEvent.ModifierFlags) -> Void)?
    var onRightClick: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { false }
    
    override func mouseDown(with event: NSEvent) {
        onLeftClick?(event.modifierFlags)
        nextResponder?.mouseDown(with: event)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
        nextResponder?.rightMouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        nextResponder?.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        nextResponder?.mouseUp(with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        nextResponder?.rightMouseUp(with: event)
    }
    
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

extension View {
    func onClick(left: @escaping () -> Void, right: @escaping () -> Void) -> some View {
        modifier(
            ClickInteractionModifier(
                onLeftClick: { _ in left() },
                onRightClick: right
            )
        )
    }

    func onClick(
        left: @escaping (NSEvent.ModifierFlags) -> Void,
        right: @escaping () -> Void
    ) -> some View {
        modifier(ClickInteractionModifier(onLeftClick: left, onRightClick: right))
    }
}
