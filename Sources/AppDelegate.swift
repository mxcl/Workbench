import AppKit
import Cake

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let model = Dotfiles.Sync()
    let popover = NSPopover()
    let statusItem = NSStatusBar.system.statusItem(withLength: 24)
    var eventMonitor: Any?
    let updater = AppUpdater(owner: "mxcl", repo: "Workbench")

    var rootViewController: RootViewController? {
        return popover.contentViewController as? RootViewController
    }

    var dotfilesViewController: DotfilesViewController? {
        return rootViewController?.children.first as? DotfilesViewController
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        registerAsLoginItem()

        model.delegate = self

        let storyboard = NSStoryboard(name: .init("Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier("RootTabViewController")
        popover.contentViewController = storyboard.instantiateController(withIdentifier: identifier) as? NSViewController
    }

    @objc func checkForUpdates() {
        updater.check().catch(policy: .allErrors) { error in
            if error.isCancelled {
                alert(message: "The latest version is “\(Bundle.main.version)”.", title: "\(Bundle.main.name) is Up‐to‐Date")
            } else {
                alert(error)
            }
        }
    }
}

extension AppDelegate: Dotfiles.SyncDelegate {
    func dotfilesSyncItemsUpdated() {
        if let tableView = dotfilesViewController?.tableView {
            tableView.reloadData()
            tableViewSelectionDidChange(Notification(name: .CKAccountChanged, object: tableView, userInfo: nil))
        }
        updateStatusBarIcon()
    }

    func dotfilesSyncError(_ error: Error) {
        let note = NSUserNotification()
        note.title = error.title
        note.informativeText = error.legibleDescription
        NSUserNotificationCenter.default.deliver(note)
    }

    @IBAction func upload(sender: NSButton) {
        guard let tableView = dotfilesViewController?.tableView else { return }
        model.resolveConflictByUploading(index: tableView.selectedRow)
    }

    @IBAction func download(sender: NSButton) {
        guard let tableView = dotfilesViewController?.tableView else { return }
        model.resolveConflictByDownloading(index: tableView.selectedRow)
    }

    @IBAction func stopSyncing(sender: NSMenuItem) {
        guard let tableView = dotfilesViewController?.tableView else { return }
        model.stopSyncing(index: tableView.selectedRow)
    }
}

extension AppDelegate: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return model.items.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
        if column == dotfilesViewController?.filenameColumn {
            return model.items[row].relativePath
        } else {
            return model.items[row].statusString
        }
    }
}

extension AppDelegate: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else {
            return
        }

        let index = tableView.selectedRow
        guard index >= 0 else { return }

        rootViewController?.uploadButton?.isEnabled = true
        rootViewController?.downloadButton?.isEnabled = true

        switch model.items[index].status {
        case .networking:
            rootViewController?.uploadButton?.isEnabled = false
            rootViewController?.downloadButton?.isEnabled = false
            fallthrough
        case .error:
            rootViewController?.uploadButton?.isHidden = false
            rootViewController?.downloadButton?.isHidden = false
        default:
            rootViewController?.uploadButton?.isHidden = true
            rootViewController?.downloadButton?.isHidden = true
        }
    }
}

private extension Bundle {
    var name: String {
        func path(_ str: String) -> Path {
            return Path(str) ?? Path.cwd/str
        }

        return localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? CommandLine.arguments.first.map(path)?.basename(dropExtension: true)
            ?? "App"
    }
}
