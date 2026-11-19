import Cocoa
import PortRadarCore

final class SettingsWindowController: NSWindowController {
    private let grouped = NSButton(radioButtonWithTitle: "Grouped by project", target: nil, action: nil)
    private let simple = NSButton(radioButtonWithTitle: "Simple list", target: nil, action: nil)
    private let login = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = "PortRadar Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        for button in [grouped, simple] {
            button.target = self
            button.action = #selector(layoutChanged)
        }
        login.target = self
        login.action = #selector(loginChanged)

        let current = Layout(rawValue: UserDefaults.standard.string(forKey: "layout") ?? "") ?? .grouped
        grouped.state = current == .grouped ? .on : .off
        simple.state = current == .simple ? .on : .off
        login.state = LaunchAtLogin.isEnabled ? .on : .off
        login.isEnabled = LaunchAtLogin.isSupported && !Demo.isOn
        if !LaunchAtLogin.isSupported { login.toolTip = LoginItemError.notAnAppBundle.errorDescription }

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Layout:"), grouped],
            [NSGridCell.emptyContentView, simple],
            [NSGridCell.emptyContentView, login],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.rowSpacing = 8
        grid.row(at: 2).topPadding = 10
        grid.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -40),
        ])
        window.contentView = content
        window.center()
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func layoutChanged() {
        let layout: Layout = simple.state == .on ? .simple : .grouped
        UserDefaults.standard.set(layout.rawValue, forKey: "layout")
    }

    @objc private func loginChanged() {
        do {
            try LaunchAtLogin.setEnabled(login.state == .on)
        } catch {
            NSAlert(error: error).runModal()
        }
        login.state = LaunchAtLogin.isEnabled ? .on : .off
    }
}
