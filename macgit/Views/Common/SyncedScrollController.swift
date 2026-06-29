//
//  macgit (Commit+) - a macOS Git client built with Swift and SwiftUI.
//  Copyright (C) 2026  Thanh Tran <trantienthanh2412@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Affero General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Affero General Public License for more details.
//
//  You should have received a copy of the GNU Affero General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
import AppKit

final class SyncedScrollController {
    private var scrollViews: [String: WeakScrollView] = [:]
    private var observers: [String: NSObjectProtocol] = [:]
    private var isApplyingSynchronizedScroll = false
    private var lastRequestedOffset: CGFloat?

    func register(_ scrollView: NSScrollView, id: String) {
        removeReleasedScrollViews()

        if scrollViews[id]?.value === scrollView {
            return
        }

        unregister(id: id)
        scrollViews[id] = WeakScrollView(scrollView)

        scrollView.contentView.postsBoundsChangedNotifications = true
        observers[id] = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self, weak scrollView] _ in
            guard let self, let scrollView else { return }
            self.syncScroll(from: id, source: scrollView)
        }

        // If a scroll offset was requested before this scroll view finished
        // registering, apply it now so callers can scroll before the bridge
        // between SwiftUI and AppKit is fully wired up.
        if let lastRequestedOffset {
            setVerticalOffset(lastRequestedOffset, on: scrollView)
        }
    }

    func unregister(id: String, scrollView: NSScrollView? = nil) {
        if let scrollView, scrollViews[id]?.value !== scrollView {
            return
        }

        if let observer = observers.removeValue(forKey: id) {
            NotificationCenter.default.removeObserver(observer)
        }
        scrollViews.removeValue(forKey: id)
    }

    func scrollToTop() {
        scrollToVerticalOffset(0)
    }

    func scrollToVerticalOffset(_ offset: CGFloat) {
        removeReleasedScrollViews()
        lastRequestedOffset = offset
        isApplyingSynchronizedScroll = true
        for scrollView in scrollViews.values.compactMap(\.value) {
            setVerticalOffset(offset, on: scrollView)
        }
        isApplyingSynchronizedScroll = false
    }

    private func syncScroll(from sourceID: String, source: NSScrollView) {
        guard !isApplyingSynchronizedScroll else { return }
        removeReleasedScrollViews()

        let sourceY = source.contentView.bounds.origin.y
        isApplyingSynchronizedScroll = true

        for (id, weakScrollView) in scrollViews where id != sourceID {
            guard let scrollView = weakScrollView.value else { continue }
            setVerticalOffset(sourceY, on: scrollView)
        }

        isApplyingSynchronizedScroll = false
    }

    private func setVerticalOffset(_ offset: CGFloat, on scrollView: NSScrollView) {
        guard let documentView = scrollView.documentView else { return }

        let maximumOffset = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
        let clampedOffset = min(max(0, offset), maximumOffset)
        var origin = scrollView.contentView.bounds.origin
        origin.y = clampedOffset

        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func removeReleasedScrollViews() {
        let releasedIDs = scrollViews.compactMap { id, weakScrollView in
            weakScrollView.value == nil ? id : nil
        }

        for id in releasedIDs {
            unregister(id: id)
        }
    }
}

private final class WeakScrollView {
    weak var value: NSScrollView?

    init(_ value: NSScrollView) {
        self.value = value
    }
}
