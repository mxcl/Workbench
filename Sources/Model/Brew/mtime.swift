import PMKFoundation
import Foundation
import PromiseKit
import Path

var mtime: Guarantee<Date?> {
    func mtime(gitdir: Path) -> Promise<Date> {
        let proc = Process()
        proc.launchPath = "/usr/bin/git"
        proc.arguments = ["log", "-1", "--pretty=format:%ct"]
        proc.currentDirectoryPath = gitdir.string

        return firstly {
            proc.launch(.promise)
        }.compactMap {
            String(data: $0.out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        }.compactMap {
            TimeInterval($0)
        }.map {
            Date(timeIntervalSince1970: $0)
        }
    }

    var tapdirs: [Path] {
        do {
            return try Path.root.usr.local.Homebrew.Library.Taps.ls().map(\.path)
        } catch {
            print("Workbench:error:", error)
            return []
        }
    }

    let promises = (tapdirs + [Path.root.usr.local.Homebrew]).map(mtime)

    return when(resolved: promises).map {
        $0.compactMap{ $0.value }.max()
    }
}
