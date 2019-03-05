import AppKit
import Cake

class RootViewController: NSViewController {
    @IBOutlet var downloadButton: NSButton!
    @IBOutlet var uploadButton: NSButton!
    @IBOutlet var versionLabel: NSTextField!
    @IBOutlet var addButton: NSButton!

    private var noTabs = false

    func hideTabs() {
        noTabs = true
        tabViewController?.hideTabs()
    }

    var tabViewController: TabViewController? {
        return children.first as? TabViewController
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if noTabs {
            // `.unspecified` style means they go away
            (segue.destinationController as? TabViewController)?.hideTabs()
        }
    }

    override func viewDidLoad() {
        // fixes text not being visible in popover
        // https://github.com/mxcl/Workbench/issues/24
        // https://stackoverflow.com/questions/29074724
        if #available(OSX 10.14, *), UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" {
            view.appearance = NSAppearance(named: .darkAqua)
        } else {
            view.appearance = NSAppearance(named: .aqua)
        }
    }

    @IBAction func onMiscClicked(_ sender: Any) {
        let isOptionPressed = NSEvent.modifierFlags.contains(.option)

        let menu = NSMenu()
        menu.addItem(.init(title: "About Workbench…", action: #selector(onAboutClicked), keyEquivalent: ""))
        if isOptionPressed {
            menu.addItem(.init(title: "Check for Updates…", action: #selector(AppDelegate.checkForUpdates), keyEquivalent: ""))
        }
        menu.addItem(.separator())
        menu.addItem(.init(title: "Donate…", action: #selector(onDonateClicked), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(.init(title: "Quit Workbench", action: #selector(NSApplication.terminate), keyEquivalent: "q"))
        menu.popUp(withCorrectThemePositioningItem: menu.item(at: 0), atLocation: NSEvent.mouseLocation)
    }

    @objc func onAboutClicked(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "http://github.com/mxcl/Workbench")!)
        closeWindow()
    }

    @objc func onDonateClicked(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "http://www.patreon.com/mxcl")!)
        closeWindow()
    }

    private func closeWindow() {
        //TODO less coupling
        NSAppDelegate.close()
    }
}

class TabViewController: NSTabViewController {
    @IBOutlet var dotfilesTabViewItem: NSTabViewItem!
    @IBOutlet var brewTabViewItem: NSTabViewItem!

    fileprivate func hideTabs() {
        tabStyle = .unspecified
        selectedTabViewItemIndex = 0
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateStatusString()
    }

    override func tabView(_ tabView: NSTabView, didSelect item: NSTabViewItem?) {

        super.tabView(tabView, didSelect: item)

        let string: String
        switch item {
        case brewTabViewItem:
            let mtime = NSAppDelegate.brewModel.mtime
            let utime = NSAppDelegate.brewModel.utime
            string = "Last updated: \(ago: mtime), last checked: \(ago: utime)"
        default:
            string = "Workbench \(Bundle.main.version)"
        }

        NSAppDelegate.rootViewController?.versionLabel.stringValue = string
    }

    func updateStatusString() {
        tabView(tabView, didSelect: tabView.selectedTabViewItem)
    }
}
