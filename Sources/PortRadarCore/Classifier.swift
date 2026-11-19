import Foundation

/// Small argv helpers shared by classification and project resolution.
public enum ArgvReader {
    /// Interpreter flags that consume the following argument.
    static let flagsWithValue: Set<String> = [
        "-r", "--require", "--import", "--loader", "--experimental-loader", "--env-file",
        "--inspect-port", "--conditions", "-C", "-W", "-X", "--title",
    ]

    /// The first positional argument after the interpreter: the script being run.
    public static func script(in argv: [String]) -> String? {
        var index = 1
        while index < argv.count {
            let arg = argv[index]
            if arg == "-m" || arg == "-c" || arg == "-e" || arg == "--eval" { return nil }
            if flagsWithValue.contains(arg) { index += 2; continue }
            if arg.hasPrefix("-") { index += 1; continue }
            return arg
        }
        return nil
    }

    /// Python's `-m module`.
    static func module(in argv: [String]) -> String? {
        guard let index = argv.firstIndex(of: "-m"), index + 1 < argv.count else { return nil }
        return argv[index + 1]
    }

    /// Positional arguments after the script.
    static func positionals(after script: String, in argv: [String]) -> [String] {
        guard let index = argv.firstIndex(of: script) else { return [] }
        return argv[(index + 1)...].filter { !$0.hasPrefix("-") }
    }

    /// The value of `--flag value` or `--flag=value`.
    static func value(of flag: String, in argv: [String]) -> String? {
        for (index, arg) in argv.enumerated() {
            if arg == flag, index + 1 < argv.count { return argv[index + 1] }
            if arg.hasPrefix(flag + "=") { return String(arg.dropFirst(flag.count + 1)) }
        }
        return nil
    }

    /// For a script inside `node_modules`, the package that owns it, e.g.
    /// `…/node_modules/.bin/../vite/bin/vite.js` → `vite`,
    /// `…/node_modules/@astrojs/…` → `@astrojs/…`.
    static func owningPackage(of path: String) -> String? {
        let normalized = (path as NSString).standardizingPath
        guard let range = normalized.range(of: "/node_modules/", options: .backwards) else { return nil }
        let parts = normalized[range.upperBound...].split(separator: "/").map(String.init)
        guard let first = parts.first else { return nil }
        if first == ".bin" { return parts.count > 1 ? parts[1] : nil }
        if first.hasPrefix("@"), parts.count > 1 { return first + "/" + parts[1] }
        return first
    }
}

/// Decides what a listening process is. Pure: everything comes from argv,
/// executable path, port and resolved project.
public enum Classifier {
    static let agents: Set<String> = [
        "codex", "claude", "cursor-agent", "gemini", "opencode", "aider", "goose", "amp",
        "copilot", "grok", "kimi", "droid", "crush", "qwen",
    ]

    /// npm packages whose bin scripts are dev servers.
    static let nodePackages: [String: String] = [
        "next": "Next.js", "vite": "Vite", "astro": "Astro", "nuxt": "Nuxt", "nuxi": "Nuxt",
        "@remix-run/dev": "Remix", "@react-router/dev": "React Router", "@sveltejs/kit": "SvelteKit",
        "webpack": "Webpack", "webpack-cli": "Webpack", "webpack-dev-server": "Webpack",
        "storybook": "Storybook", "@storybook/cli": "Storybook", "parcel": "Parcel",
        "wrangler": "Wrangler", "@angular/cli": "Angular", "gatsby": "Gatsby",
        "@docusaurus/core": "Docusaurus", "vitest": "Vitest", "expo": "Expo", "@expo/cli": "Expo",
        "react-scripts": "Create React App", "@11ty/eleventy": "Eleventy", "serve": "serve",
        "http-server": "http-server", "json-server": "json-server", "vercel": "Vercel",
        "netlify-cli": "Netlify", "@nestjs/cli": "NestJS", "firebase-tools": "Firebase",
        "@vue/cli-service": "Vue CLI", "@rsbuild/core": "Rsbuild", "@rspack/cli": "Rspack",
        "turbo": "Turbo", "esbuild": "esbuild", "tsx": "Node", "ts-node": "Node", "nodemon": "Node",
        "prisma": "Prisma", "drizzle-kit": "Drizzle", "@playwright/test": "Playwright",
        "playwright": "Playwright", "convex": "Convex", "@electric-sql/pglite": "PGlite",
    ]

    /// Python entry points (script basename or `-m` module).
    static let pythonTools: [String: String] = [
        "uvicorn": "Uvicorn", "gunicorn": "Gunicorn", "hypercorn": "Hypercorn", "daphne": "Daphne",
        "flask": "Flask", "fastapi": "FastAPI", "streamlit": "Streamlit", "gradio": "Gradio",
        "jupyter": "Jupyter", "jupyter-lab": "Jupyter", "jupyter-notebook": "Jupyter",
        "jupyterlab": "Jupyter", "notebook": "Jupyter", "mkdocs": "MkDocs", "manage.py": "Django",
        "django-admin": "Django", "marimo": "marimo", "mlflow": "MLflow", "ray": "Ray",
    ]

    /// Native binaries recognised by name.
    static let binaries: [String: String] = [
        "postgres": "PostgreSQL", "postmaster": "PostgreSQL", "redis-server": "Redis",
        "valkey-server": "Valkey", "mysqld": "MySQL", "mariadbd": "MariaDB", "mongod": "MongoDB",
        "memcached": "Memcached", "nginx": "nginx", "caddy": "Caddy", "httpd": "Apache",
        "hugo": "Hugo", "ollama": "Ollama", "com.docker.backend": "Docker", "com.docker.vpnkit": "Docker",
        "vpnkit-bridge": "Docker", "OrbStack Helper": "OrbStack", "limactl": "Lima", "ssh": "SSH tunnel",
        "kubectl": "kubectl", "minio": "MinIO", "rabbitmq-server": "RabbitMQ", "temporal": "Temporal",
        "clickhouse": "ClickHouse", "meilisearch": "Meilisearch", "typesense-server": "Typesense",
        "air": "Go", "zola": "Zola", "trunk": "Trunk", "mailpit": "Mailpit", "supabase": "Supabase",
        "LM Studio": "LM Studio", "llama-server": "llama.cpp", "elasticsearch": "Elasticsearch",
    ]

    public static func identify(_ process: ProcessFacts, port: Int, project: Project?) -> Identity {
        let argv = process.argv
        let exe = process.executablePath
        let exeName = (exe as NSString).lastPathComponent
        let argv0 = argv.first.map { ($0 as NSString).lastPathComponent } ?? exeName
        let runtime = exeName.lowercased()
        let script = ArgvReader.script(in: argv)
        let scriptName = script.map { ($0 as NSString).lastPathComponent }

        func dev(_ kind: String, _ detail: String?) -> Identity {
            Identity(
                kind: kind,
                detail: detail ?? relativeDirectory(process.cwd, in: project) ?? exeName,
                category: .dev
            )
        }

        // Coding agents first: some are node scripts and would read as Node.
        if agents.contains(argv0) || agents.contains(exeName) || scriptName.map(agents.contains) == true {
            let name = agents.contains(argv0) ? argv0 : agents.contains(exeName) ? exeName : scriptName!
            return Identity(kind: name, detail: project?.name ?? name, category: .agent)
        }

        // Next.js rewrites its process title.
        if argv0.hasPrefix("next-server") || argv.first?.hasPrefix("next-server") == true {
            return dev("Next.js", nil)
        }

        // JavaScript runtimes: the framework is the package that owns the script.
        if ["node", "bun", "deno"].contains(runtime) {
            let runtimeName = ["node": "Node", "bun": "Bun", "deno": "Deno"][runtime]!
            guard let script else { return dev(runtimeName, nil) }
            if let package = ArgvReader.owningPackage(of: script) {
                let kind = nodePackages[package] ?? runtimeName
                return dev(kind, nodeDetail(package: package, kind: kind, script: script, argv: argv, process: process, project: project))
            }
            return dev(runtimeName, relativeDirectory(process.cwd, in: project) ?? scriptName)
        }

        // Python, including Xcode's `Python.app/Contents/MacOS/Python`.
        if runtime.hasPrefix("python") {
            if let module = ArgvReader.module(in: argv) {
                return dev(pythonTools[module] ?? "Python", module)
            }
            if let scriptName {
                if let tool = pythonTools[scriptName] {
                    let rest = ArgvReader.positionals(after: script!, in: argv)
                    return dev(tool, tool == "Django" ? rest.first : scriptName)
                }
                return dev("Python", scriptName)
            }
            return dev("Python", nil)
        }
        if let tool = pythonTools[argv0] { return dev(tool, argv0) }

        if runtime == "ruby" || ["rails", "puma", "rackup", "jekyll"].contains(argv0) {
            let name = argv0 == "ruby" ? (scriptName ?? "ruby") : argv0
            let kind = ["rails": "Rails", "puma": "Rails", "jekyll": "Jekyll"][name] ?? "Ruby"
            return dev(kind, name)
        }
        if runtime.hasPrefix("php") {
            return dev(scriptName == "artisan" ? "Laravel" : "PHP", scriptName)
        }
        if runtime == "java" { return dev("Java", ArgvReader.value(of: "-jar", in: argv).map { ($0 as NSString).lastPathComponent }) }
        if runtime == "beam.smp" { return dev("Elixir", nil) }
        if runtime == "dotnet" { return dev(".NET", scriptName) }

        // `go run` builds into a temp go-build directory.
        if exe.contains("/go-build") { return dev("Go", exeName) }
        if exe.contains("/target/debug/") || exe.contains("/target/release/") { return dev("Rust", exeName) }

        if let kind = binaries[exeName] ?? binaries[argv0] {
            return Identity(kind: kind, detail: exeName, category: .dev)
        }

        // macOS itself. Checked before apps: ControlCenter lives in a .app.
        for prefix in ["/System/", "/usr/libexec/", "/usr/sbin/", "/usr/bin/", "/sbin/", "/Library/Apple/"]
        where exe.hasPrefix(prefix) {
            return Identity(kind: "System", detail: exeName, category: .system)
        }

        if let range = exe.range(of: ".app/Contents/") {
            let appName = (String(exe[..<range.lowerBound]) as NSString).lastPathComponent
            return Identity(kind: "App", detail: appName, category: .app)
        }

        // A binary built in a project is a dev server; an unknown one on an
        // ephemeral port or outside any project is noise.
        if let project, port < 49152 {
            return Identity(kind: exeName, detail: relativeDirectory(process.cwd, in: project) ?? exeName, category: .dev)
        }
        return Identity(kind: exeName.isEmpty ? "Unknown" : exeName, detail: exeName, category: .other)
    }

    private static func nodeDetail(
        package: String, kind: String, script: String, argv: [String], process: ProcessFacts, project: Project?
    ) -> String {
        let rest = ArgvReader.positionals(after: script, in: argv)
        let command = (package as NSString).lastPathComponent
        // Explicit config in a subdirectory names the app: `--config tools/admin/vite.config.ts`.
        if let config = ArgvReader.value(of: "--config", in: argv) ?? ArgvReader.value(of: "-c", in: argv) {
            let directory = (config as NSString).deletingLastPathComponent
            if !directory.isEmpty, directory != "." { return directory }
        }
        if let sub = relativeDirectory(process.cwd, in: project) { return sub }
        if kind == "Node" || nodePackages[package] == nil {
            // An unrecognised package's own script: `quinecms/scripts/dev-server.mjs` → `quinecms`.
            return command
        }
        if let verb = rest.first, ["preview", "start", "serve", "dev", "watch", "storybook"].contains(verb) {
            return "\(command) \(verb)"
        }
        return "\(command) dev"
    }

    /// The working directory relative to the project root, or nil at the root.
    /// Tool-owned dot directories (`.quinecms/workspace`) are not meaningful names.
    static func relativeDirectory(_ cwd: String?, in project: Project?) -> String? {
        guard let cwd, let project, cwd.hasPrefix(project.path + "/") else { return nil }
        let relative = String(cwd.dropFirst(project.path.count + 1))
        if relative.isEmpty || relative.hasPrefix(".") { return nil }
        return relative
    }
}
