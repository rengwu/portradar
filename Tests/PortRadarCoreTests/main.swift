// PortRadarCore test runner: `swift run PortRadarCoreTests`.
// (Executable, not XCTest — this machine has Command Line Tools only.)
import PortRadarCore

let t = Harness()
runClassifierTests(t)
runProjectTests(t)
runPresentationTests(t)
if CommandLine.arguments.contains("--live") { runLiveScan() }
t.finish()
