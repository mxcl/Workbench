import AppKit

extension AppDelegate {
    func setupStatusBarItem() {
        updateStatusBarIcon()

        // using the statusItem.button’s action/target doesn’t allow us
        // to leave the button highlighted while the popover appears
        // even if we set isHighlighted in the action, this way does.
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                                                                                       
            if event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                return event
            }
                                                                                       
            if event.window == self?.statusItem.button?.window {
                self?.onStatusBarItemClicked()
                return nil
            } else {
                return event
            }
        }
    }

    func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }

        switch model.state {
        case .loading:
            button.image = .wrench
            button.appearsDisabled = true
        case .ready:
            button.image = .wrench
            button.alternateImage = nil
            button.appearsDisabled = false
        case .error:
            button.image = NSImage.wrench?.image(withTintColor: .red)
            button.alternateImage = NSImage.wrench?.image(withTintColor: .white)
            button.appearsDisabled = false
        }
    }

    @objc func onStatusBarItemClicked() {
        if popover.isShown {
            close()
        } else if let sender = statusItem.button {
            popover.contentViewController?.view.window?.makeKey()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.close()
            }
            sender.isHighlighted = true
        }
    }

    func close() {
        eventMonitor.map(NSEvent.removeMonitor)
        eventMonitor = nil

        // remove highlight after animation as per the behavior of other status-items
        var id: Any!
        id = NotificationCenter.default.addObserver(forName: NSPopover.didCloseNotification, object: popover, queue: nil) { _ in
            self.statusItem.button?.isHighlighted = false
            NotificationCenter.default.removeObserver(id!)
        }

        popover.performClose(self)
    }
}

private extension NSImage {
    static var wrench: NSImage? {
        return NSImage(named: "wrench")
    }
}

extension NSImage {
    func image(withTintColor tintColor: NSColor) -> NSImage {
        if !isTemplate {
            return self
        }

        let image = copy() as! NSImage
        image.lockFocus()

        tintColor.set()
        __NSRectFillUsingOperation(NSMakeRect(0, 0, image.size.width, image.size.height), .sourceAtop)

        image.unlockFocus()
        image.isTemplate = false

        return image
    }
}
