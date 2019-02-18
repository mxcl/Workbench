import Foundation

#if os(Linux)
let theOperationCouldNotBeCompleted = "The operation could not be completed"
#else
let theOperationCouldNotBeCompleted = "The operation couldn’t be completed."
#endif

extension Error {
    /// - Returns: A fully qualified representation of this error.
    public var legibleDescription: String {
        switch errorType {
        case .swiftError(.enum?), .swiftLocalizedError(_, .enum?):
            return "\(type(of: self)).\(self)"
        case .swiftError(.class?), .swiftLocalizedError(_, .class?):
            //TODO better
            return "\(type(of: self))"
        case .swiftError, .swiftLocalizedError:
            return String(describing: self)
        case let .nsError(nsError, domain, code):
            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                return "\(domain)(\(code), \(underlyingError.domain)(\(underlyingError.code)))"
            } else {
                return "\(domain)(\(code))"
            }
        }
    }

    /// - Returns: A fully qualified, user-visible representation of this error.
    public var legibleLocalizedDescription: String {
        switch errorType {
        case .swiftError:
            return "\(theOperationCouldNotBeCompleted) (\(legibleDescription))"
        case .swiftLocalizedError(let msg, _):
            return msg
        case .nsError(_, "kCLErrorDomain", 0):
            return "The location could not be determined."
            // ^^ Apple don’t provide a localized description for this
        case let .nsError(nsError, domain, code):
            if !localizedDescription.hasPrefix(theOperationCouldNotBeCompleted) {
                return localizedDescription
                //FIXME ^^ for non-EN
            } else if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                return underlyingError.legibleLocalizedDescription
            } else {
                // usually better than the localizedDescription, but not pretty
                return "\(theOperationCouldNotBeCompleted) (\(domain).\(code))"
            }
        }
    }

    private var errorType: ErrorType {
      #if os(Linux)
        let isNSError = self is NSError
      #else
        let foo: Any = self
        let isNSError = String(cString: object_getClassName(self)) != "_SwiftNativeNSError" && foo is NSObject
        // ^^ ∵ otherwise implicit bridging implicitly casts as for other tests
      #endif

        if isNSError {
            let nserr = self as NSError
            return .nsError(nserr, domain: nserr.domain, code: nserr.code)
        } else if let err = self as? LocalizedError, let msg = err.errorDescription {
            return .swiftLocalizedError(msg, Mirror(reflecting: self).displayStyle)
        } else {
            return .swiftError(Mirror(reflecting: self).displayStyle)
        }
    }
}

private enum ErrorType {
    case nsError(NSError, domain: String, code: Int)
    case swiftLocalizedError(String, Mirror.DisplayStyle?)
    case swiftError(Mirror.DisplayStyle?)
}
