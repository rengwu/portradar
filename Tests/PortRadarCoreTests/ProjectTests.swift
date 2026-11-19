import Foundation
import PortRadarCore

func runProjectTests(_ t: Harness) {
    let files: Set<String> = [
        "/Users/dev/Projects/mono/.git",
        "/Users/dev/Projects/mono/package.json",
        "/Users/dev/Projects/mono/apps/web/package.json",
        "/Users/dev/Projects/loose/go.mod",
        "/Users/dev/package.json",
    ]
    var r = ProjectResolver(home: "/Users/dev", exists: files.contains)

    t.checkEqual(r.project(forDirectory: "/Users/dev/Projects/mono/apps/web")?.name, "mono", ".git wins over nearer manifest")
    t.checkEqual(r.project(forDirectory: "/Users/dev/Projects/loose/cmd/api")?.path, "/Users/dev/Projects/loose", "manifest without git")
    t.checkEqual(r.project(forDirectory: "/Users/dev"), nil, "home is never a project")
    t.checkEqual(r.project(forDirectory: "/Users/dev/Downloads"), nil, "home's own package.json does not count")
    t.checkEqual(r.project(forDirectory: "/"), nil, "root")
    t.checkEqual(r.project(forDirectory: "/opt/homebrew/var/postgresql@16"), nil, "no markers")

    let fromScript = r.project(for: ProcessFacts(pid: 1, executablePath: "/opt/homebrew/bin/node",
        argv: ["node", "/Users/dev/Projects/loose/server.js"], cwd: "/Users/dev"))
    t.checkEqual(fromScript?.name, "loose", "falls back to the script's directory")
}
