import Foundation

extension App {
    private var isAlreadyLoginItem: Bool {
        guard
            let loginItemsRef = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue() as LSSharedFileList?,
            let loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil)?.takeRetainedValue() as? [LSSharedFileListItem]
        else {
            return true
            // ^^ error in a way that we don't add ourselves every-single-time
        }
        let appUrl = Bundle.main.bundleURL
        let itemUrl = UnsafeMutablePointer<Unmanaged<CFURL>?>.allocate(capacity: 1)
        defer { itemUrl.deallocate() }

        for i in loginItems {
            if let itemUrl = LSSharedFileListItemCopyResolvedURL(i, 0, nil), itemUrl.takeRetainedValue() as URL == appUrl {
                return true
            }
        }
        return false
    }

    func registerAsLoginItem() {
    #if !DEBUG
        guard !isAlreadyLoginItem else { return }

        let type = kLSSharedFileListSessionLoginItems.takeUnretainedValue()
        if let ref = LSSharedFileListCreate(nil, type, nil)?.takeRetainedValue() as LSSharedFileList? {
            let appUrl = Bundle.main.bundleURL as CFURL
            LSSharedFileListInsertItemURL(ref, kLSSharedFileListItemBeforeFirst.takeRetainedValue(), nil, nil, appUrl, nil, nil)
        }
    #endif
    }
}
