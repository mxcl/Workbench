import OrderedSet
import PromiseKit
import CloudKit
import Bakeware

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
                db.perform(.init(recordType: .recordType, predicate: .init(value: true)))
            }.mapValues {
                Item(record: $0)
            }.map {
                Model(items: $0)
            }.pipe(to: seal.resolve)
        }
    }
}
