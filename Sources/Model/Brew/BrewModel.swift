import PMKFoundation
import Foundation
import PromiseKit
import Bakeware
import Path

public enum E: Error {
    case noBrew
}

//TODO other brew prefixes
//TODO check for too old Homebrew

public class BrewModel {

    public struct Item {
        public let name: String
        public let version: String
        public let outdated: String?
        public let mtime: Date?
    }

    public var listing: [Item] {
        return items.value ?? []
    }

    var outdatedCount: Int {
        return listing.filter{ $0.outdated != nil }.count
    }

    var isAlerting: Bool {
        return outdatedCount > 0
    }

    public var promise: Promise<Void> {
        return items.asVoid()
    }

    public init() {
        updater = NSBackgroundActivityScheduler(identifier: "dev.mxcl.Workbench.brew-update")
        updater.repeats = true
        updater.interval = 60 * 60
        updater.schedule { [unowned self] completion in
            guard !self.updater.shouldDefer else {
                return completion(.deferred)
            }
            self.brewUpdate().then(self.reflect).log().finally {
                completion(.finished)
            }
        }

        cellarWatcher.observe = [Path.root.usr.local.opt]
        cellarWatcher.delegate = self

        items.catch { [weak self] in
            if case E.noBrew = $0 {
                self?.updater.invalidate()
            }
        }
    }

    deinit {
        updater.invalidate()
    }

    private let cellarWatcher = FSWatcher()
    private let updater: NSBackgroundActivityScheduler
    private var items = get()

    private func brewUpdate() -> Promise<Void> {
        let proc = Process()
        proc.launchPath = "/usr/local/bin/brew"
        proc.arguments = ["update"]
        return proc.launch(.promise).asVoid()
    }

    func openHomepageInBrowser(forIndex index: Int) -> Promise<Void> {
        guard let item = listing[safe: index] else { return Promise(error: PMKError.badInput) }
        let proc = Process()
        proc.launchPath = "/usr/local/bin/brew"
        proc.arguments = ["home", item.name]
        return proc.launch(.promise).asVoid()
    }
}

extension BrewModel: FSWatcherDelegate {
    public func fsWatcher(diff: FSWatcher.Diff) {
        reflect().log()
    }

    func reflect() -> Promise<Void> {
        return firstly {
            get()
        }.done {
            self.items = .value($0)
        }
    }
}

private func get() -> Promise<[BrewModel.Item]> {

    let opt = Path.root.usr.local.opt
    guard opt.isDirectory else {
        return Promise(error: E.noBrew)
    }

    // calling `brew ls` is pretty slow, due to Ruby and brew being bloated nowadays
    var current: Promise<[(String, String, Date?)]> {
        return DispatchQueue.global().async(.promise) {
            // `Set` because opt (often) has multiple entries for the same thing nowadays
            var names = Set<String>()
            return try opt.ls().compactMap {
                try $0.path.readlink()
            }.compactMap { dst in
                let version = dst.basename()
                let name = dst.parent.basename()
                guard names.insert(name).inserted else { return nil }
                return (name, version, dst.mtime)
            }.sorted {
                $0.0 < $1.0
            }
        }
    }

    struct Outdated: Decodable {
        let name: String
        let current_version: String
    }

    var outdated: Promise<[String: String]> {
        let proc = Process()
        proc.launchPath = "/usr/local/bin/brew"
        proc.arguments = ["outdated", "--json=v1"]

        return firstly {
            proc.launch(.promise)
        }.map {
            $0.out.fileHandleForReading.readDataToEndOfFile()
        }.map {
            try JSONDecoder().decode([Outdated].self, from: $0)
        }.mapValues {
            ($0.name, $0.current_version)
        }.map {
            return Dictionary(uniqueKeysWithValues: $0)
        }
    }

    var items: Promise<[BrewModel.Item]> {
        return firstly {
            when(fulfilled: current, outdated)
        }.map { current, outdated in
            current.map { name, version, mtime in
                BrewModel.Item(name: name, version: version, outdated: outdated[name], mtime: mtime)
            }
        }
    }

    return items
}
