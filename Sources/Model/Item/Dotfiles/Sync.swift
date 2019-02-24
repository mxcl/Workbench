import OrderedSet
import PromiseKit
import CloudKit
import Bakeware
import Path
import Item

public protocol SyncDelegate: class {
    func dotfilesSyncItemsUpdated()
    func dotfilesSyncError(_ error: Error)
}

public class Sync {
    public weak var delegate: SyncDelegate?

    private let watcher = FSWatcher()
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

    private func announce(_ promise: Promise<Void>) {
        delegate?.dotfilesSyncItemsUpdated()

        promise.catch {
            self.delegate?.dotfilesSyncError($0)
        }.finally {
            self.delegate?.dotfilesSyncItemsUpdated()
        }
    }

    public func resolveConflictByUploading(index: Int) {
        guard index >= 0, index < items.count else { return }

        if let promise = items[index].replace() {
            announce(promise)
        }
    }

    public func resolveConflictByDownloading(index: Int) {
        guard index >= 0, index < items.count else { return }

        if let promise = items[index].download() {
            announce(promise)
        }
    }

    public func stopSyncing(index: Int) {
        guard index >= 0, index < items.count else { return }

        let item = items[index]

        if let promise = item.delete() {
            items.removeObject(at: index)
            announce(promise)
        }

        //TODO need an operations manager that knows if we are deleting
        // so it stops responding to fsWatcher events while the delete
        // removes on success but resumes normal behavior on failure of some kind
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
            item.upload()?.recover{ _ in }.done { [weak self] in
                self?.delegate?.dotfilesSyncItemsUpdated()
            }
        }
        delegate?.dotfilesSyncItemsUpdated()
    }
}

private extension Sequence where Element == Item {
    func first(with path: Path) -> Item? {
        return first(where: { $0.path == path })
    }
}
