import Foundation
import PortRadarCore

/// Fixed services for `--demo`: screenshots and checks that never touch real processes.
enum Demo {
    static let isOn = CommandLine.arguments.contains("--demo")

    /// `--highlight N` draws row N highlighted, for screenshots without a pointer.
    static let highlightedRow: Int? = {
        guard let flag = CommandLine.arguments.firstIndex(of: "--highlight") else { return nil }
        return CommandLine.arguments.dropFirst(flag + 1).first.flatMap { Int($0) }
    }()

    /// In demo mode, prints the action instead of performing it, and returns true.
    static func log(_ action: String) -> Bool {
        guard isOn else { return false }
        print(action)
        fflush(stdout)
        return true
    }

    static let services: [Service] = [
        make(4178, "quinecms", "Vite", "tools/admin-gallery"),
        make(4179, "quinecms", "Python", "http.server"),
        make(4321, "quinecms", "Node", "server.mjs"),
        make(4410, "quinecms", "Vite", "vite preview"),
        make(3000, "storefront", "Next.js", "next dev"),
        make(5432, nil, "PostgreSQL", "postgres"),
        make(52811, nil, "Codex", "codex", .agent),
        make(57212, nil, "Claude", "claude", .agent),
        make(6463, nil, "Discord", "Discord", .app),
        make(49152, nil, "rapportd", "rapportd", .system),
    ]

    private static func make(
        _ port: Int, _ project: String?, _ kind: String, _ detail: String, _ category: ServiceCategory = .dev
    ) -> Service {
        let facts = ProcessFacts(
            pid: Int32(port), executablePath: "/usr/local/bin/\(kind.lowercased())",
            argv: [kind.lowercased(), detail, "--port", "\(port)"], cwd: nil
        )
        return Service(
            listener: Listener(port: port, addresses: ["127.0.0.1"], process: facts),
            project: project.map { Project(path: "/Users/demo/Projects/\($0)") },
            identity: Identity(kind: kind, detail: detail, category: category)
        )
    }
}
