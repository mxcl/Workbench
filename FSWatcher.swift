import Foundation
import Path

//TODO lastEventID so at the least we can see rename events when we aren't running
// full impl: https://gist.github.com/DivineDominion/56e56f3db43216d9eaab300d3b9f049a


public protocol FSWatcherDelegate: AnyObject {
    func fsWatcher(diff: FSWatcher.Diff)
}

public class FSWatcher {
    public init()
    {}

    public struct Diff {

        public fileprivate(set) var changed = Set<Path>()
        public fileprivate(set) var renamed = [(from: Path, to: Path)]()
        public fileprivate(set) var deleted = Set<Path>()
    }

    private var stream: FSEventStreamRef?

    public weak var delegate: FSWatcherDelegate? {
        didSet {
            if delegate == nil {
                pause()
            } else {
                resume()
            }
        }
    }

    public var observe: Set<Path> = [] {
        didSet {
            guard observe != oldValue else { return }

            pause()
            stream = nil
            start()
        }
    }

    private func start() {
        guard stream == nil, !observe.isEmpty else {
            return
        }

        let paths = Array(observe.map(\.string)) as CFArray

        //TODO ideally a non main queue run loop

        var context = FSEventStreamContext(version: 0, info: UnsafeMutableRawPointer(mutating: Unmanaged.passUnretained(self).toOpaque()), retain: nil, release: nil, copyDescription: nil)
        stream = FSEventStreamCreate(kCFAllocatorDefault, innerEventCallback, &context, paths, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0, UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagIgnoreSelf))
        FSEventStreamScheduleWithRunLoop(stream!, RunLoop.current.getCFRunLoop(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream!)
    }

    private func resume() {
        if let stream = stream { FSEventStreamStart(stream) }
    }

    private func pause() {
        if let stream = stream { FSEventStreamStop(stream) }
    }

    private let innerEventCallback: FSEventStreamCallback = { (stream, contextInfo, numEvents, eventPaths, eventFlags, eventIds) in
        let fsWatcher = unsafeBitCast(contextInfo, to: FSWatcher.self)
        let pathStrings = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
        let paths = pathStrings.compactMap(Path.init)
        
        var diff = Diff()

        for i in 0..<numEvents {
            let path = paths[i]
            let id = eventIds.advanced(by: i).pointee
            var flags = eventFlags.advanced(by: i).pointee

            if (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved)) != 0 {
                diff.deleted.insert(path)
            }
            if (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)) != 0 {
                diff.changed.insert(path)
            }
        }

        fsWatcher.delegate?.fsWatcher(diff: diff)
    }
}
