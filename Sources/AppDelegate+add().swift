import AppKit
import Cake

// gross, but whatever, it’s actually perfectly safe
private var addButton: NSButton!

extension AppDelegate {
    @IBAction func addFiles(sender: NSButton) {
        addButton = sender

        if model.items.isEmpty {
            let disabledItem = NSMenuItem(title: "The usual files most people would add, you can remove them after.", action: nil, keyEquivalent: "")
            disabledItem.isEnabled = false

            let addMenu = NSMenu()
            addMenu.addItem(.init(title: "Add Default Files", action: #selector(onAddDefaults), keyEquivalent: ""))
            addMenu.addItem(disabledItem)
            addMenu.addItem(.separator())
            addMenu.addItem(.init(title: "Add File…", action: #selector(showAddFilesPanel), keyEquivalent: ""))
            addMenu.popUp(withCorrectThemePositioningItem: addMenu.item(at: 0), atLocation: NSEvent.mouseLocation)
        } else {
            showAddFilesPanel(sender: sender)
        }
    }

    @objc private func onAddDefaults(_ sender: NSButton) {
        addButton.isEnabled = false

        firstly {
            model.add(urls: Sync.defaults.map(\.url))
        }.done {
            for case .rejected(let error) in $0 {
                guard (error as? Sync.AddError)?.kind != .noSuchFile else { continue }
                alert(error)  //TODO communicate to user
            }
            addButton.isEnabled = true
        }
    }

    @objc private func showAddFilesPanel(sender: Any) {
        guard let window = rootViewController?.view.window else { return }

        func add(_ urls: [URL]) {
            addButton.isEnabled = false

            firstly {
                model.add(urls: urls)
            }.done {
                for case .rejected(let error) in $0 {
                    alert(error)  //TODO communicate to user
                }
                addButton.isEnabled = true
            }
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.showsHiddenFiles = true
        panel.directoryURL = Path.home.url
        panel.treatsFilePackagesAsDirectories = true
        panel.isExtensionHidden = false
        panel.beginSheetModal(for: window) { rsp in
            if rsp == .OK {
                add(panel.urls)
            }
        }
    }
}
