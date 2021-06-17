import UserNotifications
import SwiftUI
import Path
import os

extension PathStruct {
    var rebased: PathStruct {
        .sink.join(relative(to: Path.home))
    }
}

extension Pathish where Self == PathStruct {
    static var sink: Self { .home.Library.join("Mobile Documents/com~apple~CloudDocs/.workbench") }
}

@main
class App: SwiftUI.App, FSWatcherDelegate {
    required init() {

        registerAsLoginItem()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
            if let error = error {
                self.logger.error("\(error.localizedDescription, privacy: .public)")
            }
        }

        let paths = [
            ".netrc",
            ".local",
            ".gnupg",
            ".ssh",
            ".gnpg",
            ".gitconfig",
            ".aws",
            ".config",
            ".zshrc"
        ].map(Path.home.join)

        logger.debug("\(Path.home, privacy: .public)")

        for file in paths {
            let dst = file.rebased
            if !dst.exists {
                _ = try? file.copy(to: dst)
            }
        }

        watcher.delegate = self
        watcher.observe = Set(paths + [.sink])
    }

    let logger = Logger()
    let watcher = FSWatcher()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    func fsWatcher(diff: FSWatcher.Diff) {
        do {
            for src in diff.changed {
                guard src.isFile else { continue }

                let dst: PathStruct
                if src.string.starts(with: Path.sink.string) {
                    // iCloud updated the file underneath us
                    dst = try .home.join(src.relative(to: .sink)).parent.mkdir(.p)
                } else {
                    dst = try .sink.join(src.relative(to: Path.home)).parent.mkdir(.p)
                }

                logger.info("cp: `\(src, privacy: .public)` to `\(dst, privacy: .public)`")

                try src.copy(.atomically, into: dst, overwrite: true)
            }
            for src in diff.renamed {
                logger.info("renamed: `\(src.from, privacy: .public)` to \(src.to, privacy: .public)")
            }
            for src in diff.deleted {
                try Path.sink.join(src.relative(to: Path.home)).delete()
                logger.info("deleted: `\(src, privacy: .public)`")
            }
        } catch {
            alert(error: error)
        }
    }

    func alert(error: Error) {
        let content = UNMutableNotificationContent()
        content.title = "Error"
        content.body = error.localizedDescription

        let uuidString = UUID().uuidString
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
        let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("\(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

extension PathStruct {
    enum Namespace { case atomically }

    func copy<P: Pathish>(_: Namespace, into dst: P, overwrite: Bool = false) throws {
        let src = self
        let tmpurl = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: dst.url, create: true)
        guard let tmp = PathStruct(url: tmpurl) else { throw CocoaError(.fileNoSuchFile) }
        let tmpfile = try src.copy(into: tmp)

        if let mtime = src.mtime {
            try FileManager.default.setAttributes([.modificationDate: mtime], ofItemAtPath: tmpfile.string)
        }

        try tmp.join(src.basename()).move(into: dst, overwrite: true)
    }
}
