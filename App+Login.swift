import Foundation

extension App {
    private var url: URL {
        // fileReferenceURLs move with the App, so work when the user moves the app
        (Bundle.main.bundleURL as NSURL).fileReferenceURL() ?? Bundle.main.bundleURL
    }

#if !DEBUG
    private var isAlreadyLoginItem: Bool {
        guard
            let ref = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue() as LSSharedFileList?,
            let loginItems = LSSharedFileListCopySnapshot(ref, nil)?.takeRetainedValue() as? [LSSharedFileListItem]
        else {
            return true
            // ^^ error in a way that we don't add ourselves every-single-time
        }

        for item in loginItems {
            if let itemUrl = LSSharedFileListItemCopyResolvedURL(item, 0, nil), itemUrl.takeRetainedValue() as URL == url {
                return true
            }
        }
        return false
    }
#endif

    func registerAsLoginItem() {
    #if !DEBUG
        guard !isAlreadyLoginItem else { return }

        let type = kLSSharedFileListSessionLoginItems.takeUnretainedValue()
        if let ref = LSSharedFileListCreate(nil, type, nil)?.takeRetainedValue() as LSSharedFileList? {
            LSSharedFileListInsertItemURL(ref, kLSSharedFileListItemBeforeFirst.takeRetainedValue(), nil, nil, url as CFURL, nil, nil)
        }
    #endif
    }
}
