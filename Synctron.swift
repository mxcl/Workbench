import Foundation
import Path
import os

protocol SynctronDelegate: AnyObject {
    func on(error: Error)
}

class Synctron: FSWatcherDelegate {
    init(logger: Logger) {
        self.logger = logger

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

        for file in paths {
            let dst = file.rebased
            if !dst.exists {
                _ = try? file.copy(to: dst)
            }
        }

        watcher.delegate = self
        watcher.observe = Set(paths + [.sink])
    }

    weak var delegate: SynctronDelegate?
    let logger: Logger
    let watcher = FSWatcher()

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
            delegate?.on(error: error)
        }
    }

}

private extension PathStruct {
    var rebased: PathStruct {
        .sink.join(relative(to: Path.home))
    }
}

private extension Pathish where Self == PathStruct {
    static var sink: Self { .home.Library.join("Mobile Documents/com~apple~CloudDocs/.workbench") }
}

private extension PathStruct {
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
