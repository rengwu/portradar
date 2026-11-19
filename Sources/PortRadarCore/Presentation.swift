import Foundation

public enum Layout: String, CaseIterable, Sendable {
    case grouped
    case simple
}

/// One menu row: port on the left, title, kind dimmed on the right.
public struct Row: Equatable, Sendable {
    public var title: String
    public var kind: String
    public var service: Service
}

public struct Section: Equatable, Sendable {
    /// nil for an untitled section (simple layout).
    public var title: String?
    public var rows: [Row]
}

public struct MenuModel: Equatable, Sendable {
    public var sections: [Section]
    /// Listeners worth showing by default; zero dims the menu bar icon.
    public var visibleCount: Int
    public var hiddenCount: Int
}

/// Turns raw listeners into services: project + identity.
public func identify(_ listeners: [Listener], resolver: inout ProjectResolver) -> [Service] {
    listeners.map { listener in
        let project = resolver.project(for: listener.process)
        let identity = Classifier.identify(listener.process, port: listener.port, project: project)
        return Service(listener: listener, project: project, identity: identity)
    }
}

public func present(_ services: [Service], layout: Layout, showHidden: Bool) -> MenuModel {
    let visible = services.filter { $0.identity.category.isShownByDefault }.sorted { $0.port < $1.port }
    let hidden = services.filter { !$0.identity.category.isShownByDefault }.sorted { $0.port < $1.port }

    var sections: [Section]
    switch layout {
    case .simple:
        let rows = visible.map {
            Row(title: $0.project?.name ?? $0.identity.detail, kind: $0.identity.kind, service: $0)
        }
        sections = rows.isEmpty ? [] : [Section(title: nil, rows: rows)]
    case .grouped:
        let groups = Dictionary(grouping: visible) { $0.project?.name }
        let named = groups.keys.compactMap { $0 }.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
        sections = named.map { name in
            Section(title: name, rows: groups[name]!.map(groupedRow))
        }
        if let loose = groups[nil] {
            sections.append(Section(title: "Other", rows: loose.map(groupedRow)))
        }
    }

    if showHidden, !hidden.isEmpty {
        sections.append(Section(title: "Hidden", rows: hidden.map {
            Row(title: $0.project?.name ?? $0.identity.detail, kind: $0.identity.kind, service: $0)
        }))
    }
    return MenuModel(sections: sections, visibleCount: visible.count, hiddenCount: hidden.count)
}

private func groupedRow(_ service: Service) -> Row {
    Row(title: service.identity.detail, kind: service.identity.kind, service: service)
}
