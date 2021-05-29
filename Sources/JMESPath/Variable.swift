import Foundation

enum Variable: Equatable {
    case null
    case string(String)
    case number(NSNumber)
    case boolean(Bool)
    case array([Variable])
    case object([String: Variable])
    case expRef(Ast)

    init(from any: Any) throws {
        switch any {
        case let string as String:
            self = .string(string)
        case let boolean as Bool:
            self = .boolean(boolean)
        case let number as NSNumber:
            self = .number(number)
        case let array as [Any]:
            self = try .array(array.map { try .init(from: $0) })
        case let dictionary as [String: Any]:
            self = try .object(dictionary.mapValues { try .init(from: $0) })
        default:
            let mirror = Mirror(reflecting: any)
            guard mirror.children.count > 0 else {
                throw JMESError.failedToCreateLiteral
            }
            var dictionary: [String: Variable] = [:]
            for child in mirror.children {
                guard let label = child.label else { throw JMESError.failedToCreateLiteral }
                guard let unwrapValue = unwrap(child.value) else { throw JMESError.failedToCreateLiteral }
                dictionary[label] = try Variable(from: unwrapValue)
            }
            self = .object(dictionary)
        }
    }

    func collapse() -> Any? {
        switch self {
        case .null:
            return nil
        case .string(let string):
            return string
        case .number(let number):
            return number
        case .boolean(let bool):
            return bool
        case .array(let array):
            return array.map { $0.collapse() }
        case .object(let map):
            return map.mapValues { $0.collapse() }
        case .expRef:
            return nil
        }
    }

    func getField(_ key: String) -> Variable {
        if case .object(let object) = self {
            return object[key] ?? .null
        }
        return .null
    }

    func getIndex(_ index: Int) -> Variable {
        if case .array(let array) = self {
            if index >= 0, index < array.count {
                return array[index]
            } else if index < 0, index >= -array.count {
                return array[array.count + index]
            }
        }
        return .null
    }

    func slice(start: Int?, stop: Int?, step: Int) -> [Variable]? {
        if case .array(let array) = self {
            return array.slice(start: start, stop: stop, step: step)
        }
        return nil
    }

    func isTruthy() -> Bool {
        switch self {
        case .boolean(let bool): return bool
        case .string(let string): return !string.isEmpty
        case .array(let array): return !array.isEmpty
        case .object(let object): return !object.isEmpty
        case .number: return true
        default: return false
        }
    }

    func compare(_ comparator: Comparator, value: Variable) -> Bool? {
        switch comparator {
        case .equal: return self == value
        case .notEqual: return self != value
        default:
            if case .number(let lhs) = self, case .number(let rhs) = value {
                switch comparator {
                case .lessThan: return lhs.doubleValue < rhs.doubleValue
                case .lessThanOrEqual: return lhs.doubleValue <= rhs.doubleValue
                case .greaterThan: return lhs.doubleValue > rhs.doubleValue
                case .greaterThanOrEqual: return lhs.doubleValue >= rhs.doubleValue
                default:
                    break
                }
            }
        }
        return nil
    }
}

func unwrap(_ any: Any) -> Any? {
    let mirror = Mirror(reflecting: any)
    guard mirror.displayStyle == .optional else { return any }
    guard let first = mirror.children.first else { return nil }
    return first.value
}

extension Mirror {
    func getAttribute(forKey key: String) -> Any? {
        guard let matched = children.filter({ $0.label == key }).first else {
            return nil
        }
        return unwrap(matched.value)
    }
}

extension Array {
    func slice(start: Int?, stop: Int?, step: Int) -> [Element] {
        let start2 = start ?? (step > 0 ? 0 : self.count - 1)
        let stop2 = stop ?? (step > 0 ? self.count : -1)

        if start2 <= stop2 {
            let slice = self[start2..<stop2]
            guard step > 0 else { return [] }
            return slice.everyOther(step: step)
        } else {
            let slice = self[(stop2 + 1)..<(start2 + 1)].reversed().map { $0 }
            guard step < 0 else { return [] }
            return slice.everyOther(step: -step)
        }
    }
}

extension RandomAccessCollection {
    func everyOther(step: Int) -> [Element] {
        if step == 0 {
            return []
        }
        if step == 1 {
            return self.map { $0 }
        }
        var newArray: [Element] = []
        var index = startIndex
        while index < endIndex {
            newArray.append(self[index])
            index = self.index(index, offsetBy: step)
        }
        return newArray
    }
}
