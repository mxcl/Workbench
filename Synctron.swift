import Foundation
import Path
import os

protocol SynctronDelegate: AnyObject {
    func on(error: Error)
}

class Synctron: FSWatcherDelegate {
    init(logger: Logger) {
        self.logger = logger

        let paths = Path.sink.ls(.a).map{ $0.basename() }.map(Path.home.join)

        logger.debug("watching: \(paths.map(\.string).joined(separator: ", "), privacy: .public)")

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

    func fsWatcher(event: FSWatcher.Event, path: Path) {
        if event == .created, path.isSunk {
            watcher.observe.insert(path)
        } else {
            do {
                try handle(event: event, path: path)
            } catch {
                delegate?.on(error: error)
            }
        }
    }

    func handle(event: FSWatcher.Event, path src: Path) throws {
        switch event {
        case .modified, .created:
            guard src.isFile else {
                logger.warning("file didn’t exist: \(src, privacy: .public)")
                return
            }

            let dst: PathStruct
            if src.string.starts(with: Path.sink.string) {
                // iCloud updated the file underneath us
                dst = try .home.join(src.relative(to: .sink)).parent.mkdir(.p)
            } else {
                dst = try .sink.join(src.relative(to: Path.home)).parent.mkdir(.p)
            }

            logger.info("cp: `\(src, privacy: .public)` to `\(dst, privacy: .public)`")

            try src.copy(.atomically, into: dst, overwrite: true)
        case .deleted:
            let dst = Path.sink.join(src.relative(to: Path.home))
            if dst.isFile {
                try dst.delete()
                logger.info("deleted: `\(dst, privacy: .public)`")
            } else {
                logger.warning("file didn’t exist: \(dst, privacy: .public)")
            }
        }
    }
}

private extension PathStruct {
    var rebased: PathStruct {
        let home = Path(Path.home)
        var (src, dst) = (home, Path.sink)
        if self.string.hasPrefix(home.string) {
            (src, dst) = (dst, src)
        }
        return src.join(self.relative(to: dst))
    }

    var isSunk: Bool {
        string.hasPrefix(Path.sink.string)
    }
}

extension Pathish where Self == PathStruct {
    static var sink: Self { .home.Library.join("Mobile Documents/com~apple~CloudDocs/.workbench") }
}

private extension PathStruct {
    enum Namespace { case atomically }

    func copy<P: Pathish>(_: Namespace, into dst: P, overwrite: Bool = false) throws {
        let src = self
        let dst = dst.join(src.basename())
        let fm = FileManager()
        let tmpurl = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: dst.url, create: true)
        guard let tmp = PathStruct(url: tmpurl) else { throw CocoaError(.fileNoSuchFile) }
        let tmpfile = try src.copy(into: tmp)

        if let mtime = src.mtime {
            try fm.setAttributes([.modificationDate: mtime], ofItemAtPath: tmpfile.string)
        }

        //try fm.replaceItem(at: dst.url, withItemAt: tmpfile.url, backupItemName: nil, options: [], resultingItemURL: nil)

        try tmp.join(src.basename()).move(into: dst, overwrite: true)
    }
}
