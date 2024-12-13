public struct JMESArray {
    private enum _Internal {
        case any([Any])
        case variables([JMESVariable])
    }
    private let value: _Internal
    private init(_ value: _Internal) {
        self.value = value
    }

    static func any(_ array: [Any]) -> Self { .init(.any(array)) }
    static func variables(_ array: [JMESVariable]) -> Self { .init(.variables(array)) }

    func collapse() -> [Any] {
        switch self.value {
        case .any(let array):
            array
        case .variables(let array):
            array.map { $0.collapse()! }
        }
    }
}

extension JMESArray: Collection, RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = Any

    public var startIndex: Int {
        switch self.value {
        case .any(let array):
            array.startIndex
        case .variables(let array):
            array.startIndex
        }

    }
    public var endIndex: Int {
        switch self.value {
        case .any(let array):
            array.endIndex
        case .variables(let array):
            array.endIndex
        }
    }

    public func count() -> Int {
        switch self.value {
        case .any(let array):
            array.count
        case .variables(let array):
            array.count
        }
    }

    public subscript(position: Int) -> Any {
        switch self.value {
        case .any(let array):
            array[position]
        case .variables(let array):
            array[position].collapse()!
        }
    }

    public subscript(variable position: Int) -> Any {
        switch self.value {
        case .any(let array):
            JMESVariable(from: array[position])
        case .variables(let array):
            array[position]
        }
    }
}

extension JMESArray {
    /// calculate actual index. Negative indices read backwards from end of array
    func calculateIndex(_ index: Int) -> Int {
        if index >= 0 {
            return index
        } else {
            return count + index
        }
    }
}
