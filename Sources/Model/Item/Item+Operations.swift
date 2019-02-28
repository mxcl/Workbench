import PMKCloudKit
import Foundation
import PromiseKit
import CloudKit
import Dispatch
import Bakeware
import Path

public extension Item {
    /// returns a new promise that is intended for user-communication only
    private func reflect() -> Promise<Void> {
        guard case .networking(let promise) = status else {
            return Promise(error: StateMachineError())
        }

        return promise.done(on: .main) {
            guard case .networking(let ongoingPromise) = self.status, ongoingPromise === promise else {
                // new networking operations occurred in the meantime
                // this promise is now irrelevant
                throw PMKError.cancelled
            }
            self.status = .init(record: self.record)

        }.recover(on: .main, policy: .allErrors) { error in
            guard case .networking(let ongoingPromise) = self.status, ongoingPromise === promise else {
                // new networking operations occurred in the meantime
                // this promise is now irrelevant
                throw PMKError.cancelled
            }
            if error.isCancelled {
                self.status = .init(record: self.record)  // might be “conflict” state
            } else {
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

    #if DEBUG
        func save() -> Promise<Void> {
            return db.save(self.record).done {
                assert($0 === self.record)
            }
        }
    #else
        let save = { db.save(self.record).asVoid() }
    #endif

        func go() -> Promise<Void> {
            var retries = 0

            return DispatchQueue.global().async(.promise) {
                { ($0, $0.md5) }(try Data(contentsOf: self.path))
            }.get { data, md5 in
                if (self.record[.checksum] as? String) == md5 {
                    throw PMKError.cancelled
                }
            }.done { data, md5 in
                self.record[.data] = data as CKRecordValue
                self.record[.checksum] = md5 as CKRecordValue
            }.then {
                save()
            }.recover { error -> Promise<Void> in

                // for CloudKit time-outs or no Internet, keep trying

                guard error.shouldRetry else {
                    throw error
                }
                return after(.seconds(2)).done {
                    retries += 1
                    guard retries < 3 else { throw error }
                }.then(go)
            }
        }

        func recover(error: Error) throws -> Promise<Void> {
            if error.isCancelled || error.shouldRetry {
                return Promise()
            } else {
                throw error
            }
        }

        switch status {
        case .error:
            print("warning: will not upload while in error state")
            return nil
        case .networking(let promise):
            status = .networking(promise.recover(recover).then(go))
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
