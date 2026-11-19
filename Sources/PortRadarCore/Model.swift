import Foundation

/// What the kernel says about one process that owns a listening socket.
public struct ProcessFacts: Equatable, Sendable {
    public var pid: Int32
    /// Absolute path of the running executable (`proc_pidpath`).
    public var executablePath: String
    /// The original argument vector. Some runtimes rewrite it (Next.js sets
    /// `next-server (vX)` as its title), which classification relies on.
    public var argv: [String]
    /// Working directory; nil when the kernel will not tell us.
    public var cwd: String?

    public init(pid: Int32, executablePath: String, argv: [String], cwd: String?) {
        self.pid = pid
        self.executablePath = executablePath
        self.argv = argv
        self.cwd = cwd
    }
}

/// One listening TCP port, merged across IPv4/IPv6 and duplicate fds.
public struct Listener: Equatable, Sendable {
    public var port: Int
    /// Bound local addresses, e.g. `127.0.0.1`, `::1`, `*`.
    public var addresses: [String]
    public var process: ProcessFacts

    public init(port: Int, addresses: [String], process: ProcessFacts) {
        self.port = port
        self.addresses = addresses
        self.process = process
    }
}

public struct Project: Equatable, Hashable, Sendable {
    public var name: String
    public var path: String

    public init(path: String) {
        self.path = path
        self.name = (path as NSString).lastPathComponent
    }
}

/// Why a listener is or is not shown by default.
public enum ServiceCategory: Equatable, Sendable {
    /// Dev servers and local services (databases, Docker). Shown.
    case dev
    /// Coding-agent CLIs on random ports (codex, claude…). Hidden.
    case agent
    /// GUI applications and their helpers. Hidden.
    case app
    /// macOS daemons. Hidden.
    case system
    /// Unrecognised and not inside a project, or on an ephemeral port. Hidden.
    case other

    public var isShownByDefault: Bool { self == .dev }
}

public struct Identity: Equatable, Sendable {
    /// Human name of what is running: "Vite", "Next.js", "Python", "PostgreSQL".
    public var kind: String
    /// What distinguishes this process inside its project: "vite preview",
    /// "http.server", "tools/admin-gallery".
    public var detail: String
    public var category: ServiceCategory

    public init(kind: String, detail: String, category: ServiceCategory) {
        self.kind = kind
        self.detail = detail
        self.category = category
    }
}

/// A listener with everything the menu needs.
public struct Service: Equatable, Sendable {
    public var listener: Listener
    public var project: Project?
    public var identity: Identity

    public init(listener: Listener, project: Project?, identity: Identity) {
        self.listener = listener
        self.project = project
        self.identity = identity
    }

    public var port: Int { listener.port }
    public var pid: Int32 { listener.process.pid }
    public var url: URL { URL(string: "http://localhost:\(listener.port)")! }
    public var commandLine: String { listener.process.argv.joined(separator: " ") }
}
