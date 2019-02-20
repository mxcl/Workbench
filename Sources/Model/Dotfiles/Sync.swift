import OrderedSet
import PromiseKit
import CloudKit
import Bakeware
import Path

public protocol SyncDelegate: class {
    func dotfilesSyncItemsUpdated()
    func dotfilesSyncError(_ error: Error)
}

public class Sync {
    let watcher = FSWatcher()
    var operations: [Item: Promise<Void>] = [:]
    public weak var delegate: SyncDelegate?
    private var model: Promise<Model>

    public init() {
        model = Promise()
        watcher.delegate = self

        model.done { [weak self] in
            guard let `self` = self else { return }
            self.watcher.observe = Set($0.items.map(\.path))
            self.delegate?.dotfilesSyncItemsUpdated()
        }.catch { [weak self] error in
            self?.delegate?.dotfilesSyncError(error)
        }
    }

    public var items: OrderedSet<Item> {
        return model.value?.items ?? OrderedSet()
    }

    public enum State {
        case loading(Promise<Void>)
        case ready
        case error(Error)
    }

    public var state: State {
        switch model.result {
        case .none:
            return .loading(model.asVoid())
        case .some(.fulfilled(let model)):
            for item in model.items {
                if case .error(let error) = item.status {
                    return .error(error)
                }
            }
            return .ready
        case .some(.rejected(let error)):
            return .error(error)
        }
    }

    public func resolveConflictByUploading(index: Int) {
        guard index >= 0, index < items.count else { return }
        let item = items[index]
        switch item.status {
        case .synced:
            break
        case .error:
            upload(item: item, overwrite: true)
        case .networking:
            break
        }
    }

    public func resolveConflictByDownloading(index: Int) {
        guard index >= 0, index < items.count else { return }
        //TODO
    }

    public func stopSyncing(index: Int) {
        guard index >= 0, index < items.count else { return }
        stopSyncing(item: items[index])
    }
}

extension Sync: FSWatcherDelegate {
    public func fsWatcher(diff: FSWatcher.Diff) {
        //TODO other parts of the diff
        for changedPath in diff.changed {
            guard let item = items.first(with: changedPath) else {
                //TODO Sentry
                continue
            }

            if case .error = item.status {
                return
            }

            upload(item: item, overwrite: false)
        }

        delegate?.dotfilesSyncItemsUpdated()
    }
}

private extension Sequence where Element == Item {
    func first(with path: Path) -> Item? {
        return first(where: { $0.path == path })
    }
}
