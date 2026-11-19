import Foundation
import PortRadarCore

func service(_ port: Int, _ project: String?, _ kind: String, _ detail: String, _ category: ServiceCategory = .dev) -> Service {
    Service(
        listener: Listener(port: port, addresses: ["127.0.0.1"], process: ProcessFacts(pid: Int32(port), executablePath: "", argv: [], cwd: nil)),
        project: project.map { Project(path: "/p/" + $0) },
        identity: Identity(kind: kind, detail: detail, category: category)
    )
}

func runPresentationTests(_ t: Harness) {
    let services = [
        service(4410, "landing", "Vite", "vite preview"),
        service(4179, "quinecms", "Python", "http.server"),
        service(4178, "quinecms", "Vite", "tools/admin-gallery"),
        service(5432, nil, "PostgreSQL", "postgres"),
        service(54540, "quinecms", "codex", "quinecms", .agent),
        service(6463, nil, "App", "Discord", .app),
    ]

    let grouped = present(services, layout: .grouped, showHidden: false)
    t.checkEqual(grouped.sections.map(\.title), ["landing", "quinecms", "Other"], "groups sorted, loose services last")
    t.checkEqual(grouped.sections[1].rows.map(\.title), ["tools/admin-gallery", "http.server"], "rows by port, titled by detail")
    t.checkEqual(grouped.visibleCount, 4, "visible count")
    t.checkEqual(grouped.hiddenCount, 2, "hidden count")

    let simple = present(services, layout: .simple, showHidden: false)
    t.checkEqual(simple.sections.count, 1, "simple is one section")
    t.checkEqual(simple.sections[0].rows.map(\.title), ["quinecms", "quinecms", "landing", "postgres"], "simple titles are projects")
    t.checkEqual(simple.sections[0].rows.map(\.service.port), [4178, 4179, 4410, 5432], "simple sorted by port")

    let all = present(services, layout: .simple, showHidden: true)
    t.checkEqual(all.sections.last?.title, "Hidden", "show all appends hidden section")
    t.checkEqual(all.sections.last?.rows.map(\.title), ["Discord", "quinecms"], "hidden rows")

    t.checkEqual(present([], layout: .grouped, showHidden: false).sections, [], "empty")
    t.checkEqual(services[0].url.absoluteString, "http://localhost:4410", "url is localhost")
}

/// `swift run PortRadarCoreTests --live`: prints what this machine is running.
func runLiveScan() {
    let start = Date()
    let listeners = Scanner.scan()
    var resolver = ProjectResolver()
    let services = identify(listeners, resolver: &resolver)
    print(String(format: "scan: %d listeners in %.1f ms", listeners.count, Date().timeIntervalSince(start) * 1000))
    for s in services {
        print("\(s.port)\t\(s.identity.category)\t\(s.project?.name ?? "-")\t\(s.identity.kind)\t\(s.identity.detail)\t\(s.listener.addresses)")
    }
}
