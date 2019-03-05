import PMKFoundation
import Foundation
import PromiseKit
import Bakeware
import Path

public enum E: Error {
    case noBrew
}

public protocol BrewModelDelegate: class {
    func brewItemsUpdated()
}

//TODO other brew prefixes
//TODO check for too old Homebrew

public class BrewModel {
    public weak var delegate: BrewModelDelegate?

    private var items: Promise<[Item]> = Promise()
    private var updater: Updater! = Updater()
    private let cellarWatcher = FSWatcher()

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

    public var mtime: Date? {
        return _mtime.value ?? nil
    }

    public var utime: Date? {
        return updater.utime
    }

    private var _mtime = Brew.mtime

    public init() {
        running = when(fulfilled: items, _mtime).asVoid()

        updater.delegate = self

        cellarWatcher.observe = [Path.root.usr.local.opt]
        cellarWatcher.delegate = self

        items.catch { [weak self] in
            if case E.noBrew = $0 {
                self?.updater = nil
            }
        }

        running.done { [weak self] in
            self?.delegate?.brewItemsUpdated()
        }.log()
    }

    var running: Promise<Void>

    func reflect() -> Promise<Void> {
        dispatchPrecondition(condition: .onQueue(.main))

        if !running.isPending {
            running = when(fulfilled: Promise<[Item]>(), Brew.mtime).done { [weak self] in
                self?.items = .value($0.0)
                self?._mtime = .value($0.1)
                self?.delegate?.brewItemsUpdated()
            }
        }
        return running
    }
}

extension BrewModel: UpdaterDelegate
{}

extension BrewModel: FSWatcherDelegate {
    public func fsWatcher(diff: FSWatcher.Diff) {
        reflect().log()
    }
}
