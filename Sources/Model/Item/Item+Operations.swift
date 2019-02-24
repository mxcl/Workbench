import PMKCloudKit
import Foundation
import PromiseKit
import CloudKit
import Dispatch
import Bakeware
import Path

import AppKit

public extension Item {
    /// returns a new promise that is intended for user-communication only
    private func reflect() -> Promise<Void> {
        guard case .networking(let promise) = status else {
            return Promise(error: StateMachineError())
        }

        return promise.done {
            // see if we’re done or not
            guard case .networking(let ongoingPromise) = self.status else { return }

            guard ongoingPromise === promise else {
                // we are no longer the last promise in the chain, forget about
                // this promise, it is now irrelevant
                throw PMKError.cancelled
            }

            switch promise.result {
            case .none:
                throw StateMachineError()

            case .fulfilled?:
                self.status = .init(record: self.record)

            case .rejected(let error)?:
                self.status = .error(error)
                throw error
            }
        }
    }

    private func validate(record: CKRecord) {
        assert(record === self.record)
    }

    func upload() -> Promise<Void>? {
        dispatchPrecondition(condition: .onQueue(.main))

        func save() -> Promise<Void> {
            let p = db.save(self.record)
        #if DEBUG
            return p.done {
                assert($0 === self.record)
            }
        #else
            return p.asVoid()
        #endif
        }

        func go() -> Promise<Void> {
            return DispatchQueue.global().async(.promise) {
                { ($0, $0.md5) }(try Data(contentsOf: self.path))
            }.get { data, md5 in
                if (self.record[.checksum] as? String) == md5 {
                    let alert = NSAlert()
                    alert.informativeText = "NO DIFF"
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }.done { data, md5 in
                self.record[.data] = data as CKRecordValue
                self.record[.checksum] = md5 as CKRecordValue
            }.then {
                save()
            }.recover { error -> Promise<Void> in

                // for CloudKit time-outs or no Internet, keep trying

                guard error.shouldRetry else { throw error }
                return after(.seconds(2)).then(go)
            }
        }

        switch status {
        case .error:
            print("warning: will not upload while in error state")
            return nil
        case .networking(let promise):
            status = .networking(promise.then(go))
        case .synced:
            status = .networking(go())
        }

        return reflect()
    }

    func download() -> Promise<Void>? {
        dispatchPrecondition(condition: .onQueue(.main))

        guard case .error = status else {
            print("warning: will not download while in non-error state")
            return nil
        }

        status = .networking(firstly {
            db.fetch(withRecordID: record.recordID)
        }.get {
            self.record = $0
        }.compactMap {
            $0[.data] as? Data
        }.done {
            try $0.write(to: self.path)
        })

        return reflect()
    }

    func replace() -> Promise<Void>? {
        dispatchPrecondition(condition: .onQueue(.main))

        guard case .error = status else {
            return nil
        }

        let op = CKModifyRecordsOperation()
        op.recordsToSave = [record]
        op.savePolicy = .changedKeys

        let p = DispatchQueue.global().async(.promise) {
            { ($0, $0.md5) }(try Data(contentsOf: self.path))
        }.done { data, md5 in
            self.record[.data] = data as CKRecordValue
            self.record[.checksum] = md5 as CKRecordValue
        }.then {
            Promise<Void> { seal in
                op.modifyRecordsCompletionBlock = { _, _, error in seal.resolve(error) }
                db.add(op)
            }
        }

        status = .networking(p)

        return reflect()
    }

    func delete() -> Promise<Void>? {
        dispatchPrecondition(condition: .onQueue(.main))

        switch status {
        case .synced, .error:
            return db.delete(withRecordID: record.recordID).asVoid()
        case .networking:
            return nil
        }
    }
}

private extension Error {
    var shouldRetry: Bool {
        switch self {
        case CKError.networkUnavailable, CKError.networkFailure:
            return true
        default:
            return false
        }
    }
}
