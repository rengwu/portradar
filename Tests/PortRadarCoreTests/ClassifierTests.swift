import Foundation
import PortRadarCore

let home = "/Users/dev"
let projects = "\(home)/Projects"

func facts(_ argv: [String], exe: String? = nil, cwd: String? = nil) -> ProcessFacts {
    ProcessFacts(pid: 100, executablePath: exe ?? argv[0], argv: argv, cwd: cwd)
}

func id(_ p: ProcessFacts, port: Int = 3000, project: String? = nil) -> Identity {
    Classifier.identify(p, port: port, project: project.map { Project(path: $0) })
}

/// Fixtures are command lines observed on the development machine.
func runClassifierTests(_ t: Harness) {
    let qc = "\(projects)/quinecms"

    let viteConfig = id(facts(
        ["node", "\(qc)/node_modules/.bin/../vite/bin/vite.js", "--config", "tools/admin-gallery/vite.config.ts", "--port", "4178"],
        exe: "/opt/homebrew/bin/node", cwd: qc), port: 4178, project: qc)
    t.checkEqual(viteConfig, Identity(kind: "Vite", detail: "tools/admin-gallery", category: .dev), "vite with --config subdirectory")

    let vitePreview = id(facts(
        ["node", "\(projects)/landing/node_modules/.bin/../vite/bin/vite.js", "preview", "--port", "4410"],
        exe: "/opt/homebrew/bin/node", cwd: "\(projects)/landing"), project: "\(projects)/landing")
    t.checkEqual(vitePreview, Identity(kind: "Vite", detail: "vite preview", category: .dev), "vite preview")

    let viteBare = id(facts(["node", "\(qc)/node_modules/vite/bin/vite.js"], exe: "/opt/homebrew/bin/node", cwd: qc), project: qc)
    t.checkEqual(viteBare.detail, "vite dev", "bare vite reads as vite dev")

    let viteSub = id(facts(["node", "\(qc)/node_modules/vite/bin/vite.js"], exe: "/opt/homebrew/bin/node", cwd: qc + "/apps/web"), project: qc)
    t.checkEqual(viteSub.detail, "apps/web", "monorepo package directory names the server")

    let pyServer = id(facts(
        ["/Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python",
         "-m", "http.server", "4179", "--bind", "127.0.0.1"], cwd: qc), port: 4179, project: qc)
    t.checkEqual(pyServer, Identity(kind: "Python", detail: "http.server", category: .dev), "Python.app is a runtime, not a GUI app")

    let pnpmPkg = id(facts(
        ["/Users/dev/.local/share/fnm/node-versions/v24.22.3/installation/bin/node",
         "\(projects)/demo/node_modules/.pnpm/quinecms@https+++x/node_modules/quinecms/scripts/dev-server.mjs", "--host", "127.0.0.1"],
        cwd: "\(projects)/demo/.quinecms/workspace"), port: 4322, project: "\(projects)/demo")
    t.checkEqual(pnpmPkg, Identity(kind: "Node", detail: "quinecms", category: .dev), "pnpm store package script; dot dir ignored")

    let next = id(facts(["next-server (v15.1.0)"], exe: "/opt/homebrew/bin/node", cwd: "\(projects)/shop"), project: "\(projects)/shop")
    t.checkEqual(next.kind, "Next.js", "next-server process title")

    let nextDev = id(facts(["node", "\(projects)/shop/node_modules/.bin/next", "dev"], exe: "/opt/homebrew/bin/node", cwd: "\(projects)/shop"), project: "\(projects)/shop")
    t.checkEqual(nextDev, Identity(kind: "Next.js", detail: "next dev", category: .dev), "next dev")

    let astro = id(facts(["node", "\(projects)/blog/node_modules/astro/astro.js", "dev"], exe: "/usr/local/bin/node", cwd: "\(projects)/blog"), project: "\(projects)/blog")
    t.checkEqual(astro.kind, "Astro", "astro")

    let plainNode = id(facts(["node", "server.js"], exe: "/opt/homebrew/bin/node", cwd: "\(projects)/api"), project: "\(projects)/api")
    t.checkEqual(plainNode, Identity(kind: "Node", detail: "server.js", category: .dev), "plain node script")

    let nodeRequire = id(facts(["node", "-r", "dotenv/config", "index.js"], exe: "/opt/homebrew/bin/node", cwd: "\(projects)/api"), project: "\(projects)/api")
    t.checkEqual(nodeRequire.detail, "index.js", "-r value is skipped")

    let uvicorn = id(facts(["/Users/dev/p/.venv/bin/python3", "/Users/dev/p/.venv/bin/uvicorn", "main:app", "--reload"], cwd: "\(projects)/p"), project: "\(projects)/p")
    t.checkEqual(uvicorn, Identity(kind: "Uvicorn", detail: "uvicorn", category: .dev), "uvicorn via venv python")

    let django = id(facts(["python3", "manage.py", "runserver"], exe: "/opt/homebrew/bin/python3.12", cwd: "\(projects)/site"), project: "\(projects)/site")
    t.checkEqual(django, Identity(kind: "Django", detail: "runserver", category: .dev), "django runserver")

    let goRun = id(facts(["/var/folders/x/T/go-build123/b001/exe/api"], cwd: "\(projects)/goapi"), port: 8080, project: "\(projects)/goapi")
    t.checkEqual(goRun.kind, "Go", "go run binary")

    let rust = id(facts(["\(projects)/rs/target/debug/server"], cwd: "\(projects)/rs"), port: 8000, project: "\(projects)/rs")
    t.checkEqual(rust, Identity(kind: "Rust", detail: "server", category: .dev), "cargo build output")

    let postgres = id(facts(["/opt/homebrew/opt/postgresql@16/bin/postgres", "-D", "/opt/homebrew/var/postgresql@16"], cwd: "/opt/homebrew/var/postgresql@16"), port: 5432)
    t.checkEqual(postgres, Identity(kind: "PostgreSQL", detail: "postgres", category: .dev), "homebrew postgres")

    // Hidden by default
    t.checkEqual(id(facts(["codex"], exe: "/opt/homebrew/bin/codex", cwd: qc), port: 54540, project: qc),
                 Identity(kind: "codex", detail: "quinecms", category: .agent), "codex agent shows its project")
    t.checkEqual(id(facts(["claude"], exe: "/Users/dev/.local/share/claude/versions/2.1.325", cwd: qc), port: 55368, project: qc).category,
                 .agent, "claude: binary named by version, argv0 is claude")
    t.checkEqual(id(facts(["/usr/libexec/rapportd"], cwd: "/"), port: 51970).category, .system, "rapportd")
    t.checkEqual(id(facts(["/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter"]), port: 5000).category,
                 .system, "ControlCenter is system despite .app")
    t.checkEqual(id(facts(["/Applications/Discord.app/Contents/Frameworks/Discord Helper (Renderer).app/Contents/MacOS/Discord Helper (Renderer)"]), port: 6463),
                 Identity(kind: "App", detail: "Discord", category: .app), "GUI app helper names outer app")
    t.checkEqual(id(facts(["/opt/vendor/agentd"], cwd: "/"), port: 15292).category, .other, "unknown, no project")
    t.checkEqual(id(facts(["\(projects)/tool/bin/srv"], cwd: "\(projects)/tool"), port: 9000, project: "\(projects)/tool").category,
                 .dev, "unknown binary inside a project")
    t.checkEqual(id(facts(["\(projects)/tool/bin/srv"], cwd: "\(projects)/tool"), port: 60000, project: "\(projects)/tool").category,
                 .other, "unknown binary on ephemeral port")
}
