import protocol CloudKit.CKRecordValue
import struct Foundation.Data
import PMKCloudKit
import PromiseKit
import CloudKit
import Dispatch
import Path

private extension Item {
    func upload(overwrite: Bool) -> Promise<Void> {

        let op = CKModifyRecordsOperation()
        op.recordsToSave = [record]
        op.savePolicy = overwrite ? .changedKeys : .ifServerRecordUnchanged

        return DispatchQueue.global().async(.promise) {
            let data = try Data(contentsOf: Path.home/self.relativePath)

            //FIXME are these thread safe?
            self.record[.data] = data as CKRecordValue
            self.record[.checksum] = data.md5 as CKRecordValue
        }.then {
            Promise<Void> { seal in
                op.modifyRecordsCompletionBlock = { _, _, error in seal.resolve(error) }
                db.add(op)
            }
        }.done {
            self.status = .init(record: self.record)
        }.recover {
            self.status = .error($0); throw $0
        }
    }

    func delete() -> Promise<Void> {
        return db.delete(withRecordID: record.recordID).asVoid()
    }
}

extension Sync {
    func upload(item: Item, overwrite: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))

        func go() -> Promise<Void> {
            var p: Promise<Void>!
            p = DispatchQueue.main.async(.promise) { () -> Void in
                item.status = .networking(p)
                self.delegate?.dotfilesSyncItemsUpdated()
            }.then {
                item.upload(overwrite: overwrite)
            }
            return p
        }

        if let promise = operations[item] {
            //TODO prevent too many queued changes
            operations[item] = promise.then(go)
        } else {
            operations[item] = go()
        }

        operations[item]!.ensure { [weak self] in
            if let `self` = self, let promise = self.operations[item], promise.isResolved {
                self.delegate?.dotfilesSyncItemsUpdated()
            }
        }.catch { [weak self] error in
            self?.delegate?.dotfilesSyncError(error)
        }
    }

    func stopSyncing(item: Item) {
        dispatchPrecondition(condition: .onQueue(.main))
        
        //TODO need an operations manager that knows if we are deleting
        // so it stops responding to fsWatcher events while the delete
        // removes on success but resumes normal behavior on failure of some kind

        items.remove(item)
        delegate?.dotfilesSyncItemsUpdated()

        if let promise = operations[item] {
            //TODO prevent too many queued changes
            operations[item] = promise.then(item.delete)
        } else {
            operations[item] = item.delete()
        }

        operations[item]!.ensure { [weak self] in
            if let `self` = self, let promise = self.operations[item], promise.isResolved {
                self.delegate?.dotfilesSyncItemsUpdated()
            }
        }.catch { [weak self] error in
            self?.delegate?.dotfilesSyncError(error)
        }
    }
}
