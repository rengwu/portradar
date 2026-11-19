import Foundation

/// Finds the project a process belongs to: the nearest ancestor of its working
/// directory holding `.git`, else the nearest holding a manifest. The home
/// directory and `/` are never projects.
public struct ProjectResolver {
    public static let manifests = [
        "package.json", "go.mod", "Cargo.toml", "pyproject.toml", "requirements.txt",
        "Gemfile", "composer.json", "deno.json", "mix.exs", "pom.xml", "build.gradle",
    ]

    public var home: String
    public var exists: (String) -> Bool
    private var cache: [String: Project?] = [:]

    public init(
        home: String = NSHomeDirectory(),
        exists: @escaping (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) {
        self.home = home
        self.exists = exists
    }

    /// Resolution uses the working directory first, then the directory of the
    /// script being run (for `node ~/Projects/app/server.js` started from ~).
    public mutating func project(for process: ProcessFacts) -> Project? {
        if let cwd = process.cwd, let project = project(forDirectory: cwd) { return project }
        if let script = ArgvReader.script(in: process.argv), script.hasPrefix("/"),
           !script.contains("/node_modules/") {
            return project(forDirectory: (script as NSString).deletingLastPathComponent)
        }
        return nil
    }

    public mutating func project(forDirectory directory: String) -> Project? {
        if let cached = cache[directory] { return cached }
        let found = resolve(directory)
        cache[directory] = found
        return found
    }

    private func resolve(_ directory: String) -> Project? {
        let stops: Set<String> = ["/", "", home]
        guard !stops.contains(directory), directory.hasPrefix("/") else { return nil }
        // Ignore system and temporary locations outright.
        for prefix in ["/System/", "/usr/", "/private/var/", "/var/", "/Library/", "/Applications/"]
        where directory.hasPrefix(prefix) { return nil }

        var nearestManifest: String?
        var current = directory
        while !stops.contains(current) {
            if exists(current + "/.git") { return Project(path: current) }
            if nearestManifest == nil, Self.manifests.contains(where: { exists(current + "/" + $0) }) {
                nearestManifest = current
            }
            current = (current as NSString).deletingLastPathComponent
        }
        return nearestManifest.map(Project.init(path:))
    }
}
