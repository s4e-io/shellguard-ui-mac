import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var floatingWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    let model = AppViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Install / update the bundled shellguard CLI binary on every launch
        model.installBinaryIfNeeded()

        // Popover (left-click)
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: DashboardView(model: model)
        )

        // Status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = ShellGuardIcon.make()
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Hide the empty Settings window SwiftUI creates — close only by title, safely
        DispatchQueue.main.async {
            NSApp.windows
                .filter { $0.title.contains("Settings") }
                .forEach { $0.orderOut(nil) }

            if self.model.isOnboarded {
                self.openAsWindow()
            } else {
                self.showOnboarding()
            }
        }
    }

    // MARK: - Click handling

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu(sender)
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            model.reloadState()
            model.reloadEvents()
            model.reloadPolicy()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open as Window", action: #selector(openAsWindow), keyEquivalent: "")
        openItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Shell Guard", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)
        menu.items.forEach { $0.target = self }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { self.statusItem.menu = nil }
    }

    // MARK: - Floating window

    @objc private func openAsWindow() {
        model.reloadEvents()
        model.reloadPolicy()
        if let w = floatingWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: DashboardView(model: model))
        let w = NSWindow(contentViewController: hosting)
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.title = ">_! Shell Guard"
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.setContentSize(NSSize(width: 380, height: 520))
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        floatingWindow = w
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        let view = OnboardingView(model: model) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            self?.openAsWindow()
        }
        let hosting = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: hosting)
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.title = ">_! Shell Guard"
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = w
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

// MARK: - Custom menu bar icon

enum ShellGuardIcon {
    static func make() -> NSImage {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let str = NSAttributedString(string: ">_!", attributes: attrs)
        let strSize = str.size()
        let size = NSSize(width: ceil(strSize.width) + 4, height: 18)

        let img = NSImage(size: size, flipped: false) { rect in
            let y = (rect.height - strSize.height) / 2 - 0.5
            str.draw(at: NSPoint(x: 2, y: y))
            return true
        }
        img.isTemplate = true
        return img
    }
}
