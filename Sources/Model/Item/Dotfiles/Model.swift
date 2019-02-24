import OrderedSet
import PromiseKit
import CloudKit
import Bakeware
import Item

class Model {
    var items: OrderedSet<Item>

    init(items: [Item]) {
        self.items = OrderedSet(sequence: items)
    }
}

extension Promise where T == Model {
    convenience init() {
        self.init { seal in
            firstly {
                Promise<[Item]>()
            }.map {
                Model(items: $0)
            }.pipe(to: seal.resolve)
        }
    }
}
