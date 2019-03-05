import AppKit

class BrewViewController: NSViewController {
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var formulaColumn: NSTableColumn!
    @IBOutlet var versionColumn: NSTableColumn!

    override func viewDidLoad() {
        tableView.dataSource = self
    }

    override func viewWillAppear() {
        // otherwise relative times are wrong
        tableView.reloadData()
        NSAppDelegate.updateStatusBarIcon()
    }
}

extension BrewViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return NSAppDelegate.brewModel.listing.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
        let item = NSAppDelegate.brewModel.listing[row]
        switch column {
        case formulaColumn:
            return item.name
        case versionColumn:
            return item.version
        default:
            if let outdated = item.outdated {
                return "↙ \(outdated)"
            } else {
                return "✅ \(ago: item.mtime)"
            }
        }
    }
}
