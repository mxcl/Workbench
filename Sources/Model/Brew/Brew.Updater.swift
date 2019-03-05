import PromiseKit
import Bakeware
import AppKit

protocol UpdaterDelegate: class {
    func reflect() -> Promise<Void>
}

class Updater {
    weak var delegate: UpdaterDelegate?
    private let updater: NSBackgroundActivityScheduler
    public private(set) var utime: Date?

    init() {
        updater = NSBackgroundActivityScheduler(identifier: "dev.mxcl.Workbench.brew-update")
        updater.repeats = true
        updater.interval = 60 * 60
        updater.schedule { [unowned self] completion in
            guard !self.updater.shouldDefer else {
                return completion(.deferred)
            }
            firstly {
                brewUpdate()
            }.then {
                self.delegate?.reflect() ?? Promise(error: PMKError.cancelled)
            }.log().finally {
                self.utime = Date()
                completion(.finished)
            }
        }
    }

    deinit {
        updater.invalidate()
    }
}

private func brewUpdate() -> Promise<Void> {
    let proc = Process()
    proc.launchPath = "/usr/local/bin/brew"
    proc.arguments = ["update"]
    return proc.launch(.promise).asVoid()
}
