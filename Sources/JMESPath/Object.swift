public struct JMESObject {
    private enum _Internal {
        case any([String: Any])
        case variables([String: JMESVariable])
    }
    private let object: _Internal

    private init(_ value: _Internal) {
        self.object = value
    }

    static func any(_ array: [String: Any]) -> Self { .init(.any(array)) }
    static func variables(_ array: [String: JMESVariable]) -> Self { .init(.variables(array)) }

    var isEmpty: Bool {
        switch self.object {
        case .any(let map):
            map.isEmpty
        case .variables(let map):
            map.isEmpty
        }
    }

    var count: Int {
        switch self.object {
        case .any(let map):
            map.count
        case .variables(let map):
            map.count
        }
    }

    public subscript(key: String) -> Any? {
        switch self.object {
        case .any(let map):
            map[key]
        case .variables(let map):
            map[key]?.collapse()
        }
    }

    public subscript(variable key: String) -> Any? {
        switch self.object {
        case .any(let map):
            map[key].map { JMESVariable(from: $0) }
        case .variables(let map):
            map[key]
        }
    }

    var values: [Any] {
        switch self.object {
        case .any(let map):
            map.values.map { $0 }
        case .variables(let map):
            map.values.compactMap { $0.collapse() }
        }
    }

    var keys: [String: Any].Keys {
        switch self.object {
        case .any(let map):
            map.keys
        case .variables(let map):
            map.keys
        }

    }
}

extension JMESObject {
    func collapse() -> [String: Any] {
        switch self.object {
        case .any(let map):
            map
        case .variables(let map):
            map.compactMapValues { $0.collapse() }
        }
    }
}
