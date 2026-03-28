import AppKit
import SwiftUI
import Combine

class MenuBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let dataProvider: UsageDataProvider
    private var cancellable: AnyCancellable?

    init(dataProvider: UsageDataProvider) {
        self.dataProvider = dataProvider
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(dataProvider: dataProvider).frame(width: 300)
        )

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        updateButton()

        cancellable = dataProvider.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateButton() }
            }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        let snap = dataProvider.snapshot
        let pct = Int(snap.fiveHourPct)

        let dotSize: CGFloat = 8
        let dot = NSImage(size: NSSize(width: dotSize, height: dotSize), flipped: false) { rect in
            self.nsUsageColor(snap.fiveHourPct).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            return true
        }
        dot.isTemplate = false

        button.image = dot
        button.imagePosition = .imageLeading
        button.title = snap.hasAPIData ? " \(pct)%" : ""
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    }

    private func nsUsageColor(_ pct: Double) -> NSColor {
        if pct >= 80 { return NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1) }
        if pct >= 50 { return NSColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1) }
        if pct >= 20 { return NSColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1) }
        return NSColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
