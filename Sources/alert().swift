import LegibleError
import Foundation
import AppKit

public protocol TitledError: LocalizedError {
    var title: String { get }
}

public extension Error {
    var title: String {
        if let error = self as? TitledError {
            return error.title
        }
        switch (self as NSError).domain {
        case "SKErrorDomain":
            return "App Store Error"
        case "kCLErrorDomain":
            return "Core Location Error"
        case NSCocoaErrorDomain:
            return "Error"
        default:
            return "Unexpected Error"
        }
    }
}

private func _alert(error: Error, title: String?, file: StaticString, line: UInt) -> (String, String) {
    print("\(file):\(line)", error.legibleDescription, error)
    return (error.legibleLocalizedDescription, error.title)
}

public func alert(_ error: Error, title: String? = nil, file: StaticString = #file, line: UInt = #line) {
    let (msg, title) = _alert(error: error, title: title, file: file, line: line)

    // we cannot make SKError CancellableError sadly (still)
    let pair: (String, Int) = { ($0.domain, $0.code) }(error as NSError)
    guard ("SKErrorDomain", 2) != pair else { return } // user-cancelled

    alert(message: msg, title: title)
}

public func alert(message: String, title: String) {
    func go() {
        let alert = NSAlert()
        alert.informativeText = message
        alert.messageText = title
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    DispatchQueue.main.async(execute: go)
}
