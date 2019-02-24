import AppKit

class DotfilesViewController: NSViewController {
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var filenameColumn: NSTableColumn!

    override func viewDidLoad() {
        tableView.delegate = NSApp.delegate as! AppDelegate
        tableView.dataSource = NSApp.delegate as! AppDelegate

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
