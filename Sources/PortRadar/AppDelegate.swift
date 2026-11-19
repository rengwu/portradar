import Cocoa
import PortRadarCore

/// Status item and menu. PortRadarCore decides what is listed; this projects it.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var resolver = ProjectResolver()
    private var services: [Service] = []
    private var showHidden = CommandLine.arguments.contains("--hidden")
    private var menuIsOpen = false
    private var hiddenItems: [NSMenuItem] = []
    /// Processes sent SIGTERM from the menu. One that is still listening is offered Force Quit.
    private var stopped: Set<Int32> = []
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Carry the saved layout across the bundle identifier change.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "layout") == nil,
           let previousLayout = defaults.persistentDomain(forName: "local.portia")?["layout"] as? String,
           let layout = Layout(rawValue: previousLayout) {
            defaults.set(layout.rawValue, forKey: "layout")
        }

        if Demo.isOn {
            if CommandLine.arguments.contains("--light") { NSApp.appearance = NSAppearance(named: .aqua) }
            if CommandLine.arguments.contains("--dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }
        }
        installMainMenu()
        statusItem.button?.image = MenuBarIcon.image
        statusItem.button?.setAccessibilityLabel("PortRadar")
        menu.delegate = self
        if Demo.isOn, #available(macOS 14.0, *) { menu.appearance = NSApp.appearance }
        statusItem.menu = menu

        rescan()
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            guard let self, !self.menuIsOpen else { return }
            self.rescan()
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)

        if CommandLine.arguments.contains("--settings") { openSettings() }
        if CommandLine.arguments.contains("--open") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.statusItem.button?.performClick(nil) }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    /// An `.accessory` app has no main menu by default, so ⌘, ⌘W and ⌘Q would do
    /// nothing while the settings window is in front.
    private func installMainMenu() {
        let appMenu = NSMenu(title: "PortRadar")
        appMenu.addItem(ActionItem("Settings…", key: ",") { [weak self] in self?.openSettings() })
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "Quit PortRadar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
    }

    // MARK: - Scan

    private var layout: Layout {
        if CommandLine.arguments.contains("--simple") { return .simple }
        return Layout(rawValue: UserDefaults.standard.string(forKey: "layout") ?? "") ?? .grouped
    }

    /// Scans listening sockets and updates the icon's dimmed state.
    private func rescan() {
        services = Demo.isOn
            ? Demo.services.filter { !stopped.contains($0.pid) || CommandLine.arguments.contains("--stubborn") }
            : identify(Scanner.scan(), resolver: &resolver)
        if !Demo.isOn { stopped.formIntersection(services.map(\.pid)) }
        let visible = services.filter { $0.identity.category.isShownByDefault }.count
        statusItem.button?.appearsDisabled = visible == 0
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard !menuIsOpen else { return }
        rescan()
        populate()
    }

    func menuWillOpen(_ menu: NSMenu) { menuIsOpen = true }
    func menuDidClose(_ menu: NSMenu) { menuIsOpen = false }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        for other in menu.items { (other.view as? HighlightView)?.isHighlighted = other === item }
    }

    private func populate() {
        menu.removeAllItems()
        hiddenItems = []
        // The hidden section is always built, so showing it only unhides items
        // and the open menu never has to be rebuilt.
        let model = present(services, layout: layout, showHidden: true)

        if model.visibleCount == 0 {
            let empty = NSMenuItem(title: "No servers running", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        var rowViews: [HighlightView] = []
        for (index, section) in model.sections.enumerated() {
            let isHiddenSection = model.hiddenCount > 0 && index == model.sections.count - 1
            if isHiddenSection {
                let view = DisclosureHeaderView(count: model.hiddenCount, isExpanded: showHidden)
                view.onClick = { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.setShowHidden(!self.showHidden)
                    view.isExpanded = self.showHidden
                }
                // No action: AppKit closes the menu when a click selects an item, and
                // never selects an item it cannot perform.
                let item = NSMenuItem(title: "Hidden", action: nil, keyEquivalent: "")
                item.view = view
                menu.addItem(item)
                rowViews.append(view)
            } else if let title = section.title {
                menu.addItem(header(title))
            }
            for row in section.rows {
                let view = ServiceRowView(row: row)
                let service = row.service
                view.onOpen = { Self.open(service.url) }
                view.onCopy = { Self.copy(service.url) }
                let item = NSMenuItem(title: ":\(service.port) \(row.title)", action: nil, keyEquivalent: "")
                item.view = view
                item.submenu = submenu(for: service)
                if isHiddenSection {
                    item.isHidden = !showHidden
                    hiddenItems.append(item)
                }
                menu.addItem(item)
                rowViews.append(view)
            }
        }
        menu.addItem(.separator())
        menu.addItem(ActionItem("Settings…", key: ",") { [weak self] in self?.openSettings() })
        menu.addItem(withTitle: "Quit PortRadar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let width = max(260, rowViews.map(\.frame.width).max() ?? 0)
        for view in rowViews { view.frame.size.width = width }
        if Demo.isOn, let index = Demo.highlightedRow, rowViews.indices.contains(index) {
            rowViews[index].isHighlighted = true
        }
    }

    private func setShowHidden(_ show: Bool) {
        showHidden = show
        for item in hiddenItems { item.isHidden = !show }
    }

    private func header(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) { return .sectionHeader(title: title) }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func submenu(for service: Service) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(ActionItem("Open in Browser") { Self.open(service.url) })
        menu.addItem(ActionItem("Copy URL") { Self.copy(service.url) })
        menu.addItem(.separator())
        if let project = service.project {
            menu.addItem(ActionItem("Reveal in Finder") {
                guard !Demo.log("reveal \(project.path)") else { return }
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
            })
        }
        let force = stopped.contains(service.pid)
        menu.addItem(ActionItem(force ? "Force Quit" : "Stop Process") { [weak self] in
            self?.stop(service, signal: force ? SIGKILL : SIGTERM)
        })
        return menu
    }

    // MARK: - Actions

    private static func open(_ url: URL) {
        guard !Demo.log("open \(url)") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func copy(_ url: URL) {
        guard !Demo.log("copy \(url)") else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    private func stop(_ service: Service, signal: Int32) {
        stopped.insert(service.pid)
        guard !Demo.log("kill -\(signal) \(service.pid)"), service.pid > 1 else { return }
        guard kill(service.pid, signal) != 0, errno == EPERM else { return }
        let alert = NSAlert()
        alert.messageText = "Couldn’t stop \(service.identity.kind) on port \(service.port)"
        alert.informativeText = "The process belongs to another user. PortRadar can only stop your own processes."
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc func openSettings() {
        if settingsController == nil { settingsController = SettingsWindowController() }
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
    }
}
