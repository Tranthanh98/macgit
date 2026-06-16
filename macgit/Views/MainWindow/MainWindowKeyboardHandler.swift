import SwiftUI
import AppKit

extension Notification.Name {
    static let showSearchModal = Notification.Name("showSearchModal")
}

struct MainWindowKeyboardHandler: NSViewRepresentable {
    @Binding var showingSearchModal: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        context.coordinator.setup()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.view = nsView
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(showingSearchModal: $showingSearchModal)
    }

    class Coordinator {
        @Binding var showingSearchModal: Bool
        weak var view: NSView?
        var monitor: Any?
        var observer: NSObjectProtocol?

        init(showingSearchModal: Binding<Bool>) {
            _showingSearchModal = showingSearchModal
        }

        func setup() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                // keyCode 3 = kVK_ANSI_F (physical F key)
                if event.modifierFlags.contains(.command)
                    && event.modifierFlags.contains(.shift)
                    && !event.modifierFlags.contains(.option)
                    && !event.modifierFlags.contains(.control)
                    && event.keyCode == 3
                {
                    if let view = self?.view,
                       let window = view.window,
                       window == NSApp.keyWindow
                    {
                        self?.showingSearchModal.toggle()
                        return nil
                    }
                }
                return event
            }

            observer = NotificationCenter.default.addObserver(
                forName: .showSearchModal,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                if let view = self?.view,
                   let window = view.window,
                   window == NSApp.keyWindow
                {
                    self?.showingSearchModal = true
                }
            }
        }

        func cleanup() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }
        }
    }
}
