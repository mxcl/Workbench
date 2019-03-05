import AppKit

class DotfilesViewController: NSViewController {
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var filenameColumn: NSTableColumn!

    override func viewDidLoad() {
        tableView.delegate = NSAppDelegate
        tableView.dataSource = self

        let menu = NSMenu()
        menu.addItem(withTitle: "Remove From iCloud", action: #selector(AppDelegate.stopSyncing), keyEquivalent: "")
        tableView.menu = menu
    }

    override func viewWillAppear() {
        // otherwise relative times are wrong
        tableView.reloadData()
        // otherwise upload/download buttons may be visible but shouldn’t
        tableView.delegate?.tableViewSelectionDidChange?(Notification(name: .CKAccountChanged, object: tableView, userInfo: nil))
    }
}

extension DotfilesViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return NSAppDelegate.model.items.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
        if column == filenameColumn {
            return NSAppDelegate.model.items[row].relativePath
        } else {
            return NSAppDelegate.model.items[row].statusString
        }
    }
}
