import Foundation
import PromiseKit
import Path

private struct Outdated: Decodable {
    let name: String
    let current_version: String
}

extension Promise where T == [BrewModel.Item] {
    convenience init() {
        self.init { seal in
            firstly {
                when(fulfilled: current, outdated)
            }.map { current, outdated in
                current.map { name, version, mtime in
                    BrewModel.Item(name: name, version: version, outdated: outdated[name], mtime: mtime)
                }
            }.pipe(to: seal.resolve)
        }
    }
}

// calling `brew ls` is pretty slow, due to Ruby and brew being bloated nowadays
private var current: Promise<[(String, String, Date?)]> {
    let opt = Path.root.usr.local.opt
    guard opt.isDirectory else {
        return Promise(error: E.noBrew)
    }

    return DispatchQueue.global().async(.promise) {
        // `Set` because opt (often) has multiple entries for the same thing nowadays
        var names = Set<String>()
        return try opt.ls().compactMap {
            try $0.path.readlink()
        }.compactMap { dst in
            let version = dst.basename()
            let name = dst.parent.basename()
            guard names.insert(name).inserted else { return nil }
            return (name, version, dst.mtime)
        }.sorted {
            $0.0 < $1.0
        }
    }
}

private var outdated: Promise<[String: String]> {
    let proc = Process()
    proc.launchPath = "/usr/local/bin/brew"
    proc.arguments = ["outdated", "--json=v1"]

    return firstly {
        proc.launch(.promise)
    }.map {
        $0.out.fileHandleForReading.readDataToEndOfFile()
    }.map {
        try JSONDecoder().decode([Outdated].self, from: $0)
    }.mapValues {
        ($0.name, $0.current_version)
    }.map {
        return Dictionary(uniqueKeysWithValues: $0)
    }
}
