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
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .boolean(number.boolValue)
            } else {
                self = .number(number)
            }
        case let array as [Any?]:
            self = try .array(array.map { try $0.map { try .init(from: $0)} ?? .null })
        case let dictionary as [String: Any?]:
            self = try .object(dictionary.mapValues { try $0.map { try .init(from: $0)} ?? .null })
        default:
            if any is NSNull {
                self = .null
                return
            }
            let mirror = Mirror(reflecting: any)
            guard mirror.children.count > 0 else {
                throw JMESError.failedToCreateLiteral
            }
            var dictionary: [String: Variable] = [:]
            for child in mirror.children {
                guard let label = child.label else {
                    throw JMESError.failedToCreateLiteral
                }
                guard let unwrapValue = unwrap(child.value) else {
                    throw JMESError.failedToCreateLiteral
                }
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
            let index = array.calculateIndex(index)
            if index >= 0, index < array.count {
                return array[index]
            }
        }
        return .null
    }

    func slice(start: Int?, stop: Int?, step: Int) -> [Variable]? {
        if case .array(let array) = self, step != 0 {
            return array.slice(
                start: start.map { array.calculateIndex($0) },
                stop: stop.map { array.calculateIndex($0) },
                step: step
            )
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
    func calculateIndex(_ index: Int) -> Int {
        if index >= 0 {
            return index
        } else {
            return count + index
        }
    }
    
    func slice(start: Int?, stop: Int?, step: Int) -> [Element] {
        var start2 = start ?? (step > 0 ? 0 : self.count - 1)
        var stop2 = stop ?? (step > 0 ? self.count : -1)

        if step > 0 {
            start2 = Swift.min(Swift.max(start2, 0), count)
            stop2 = Swift.min(Swift.max(stop2, 0), count)
        } else {
            start2 = Swift.min(Swift.max(start2, -1), count-1)
            stop2 = Swift.min(Swift.max(stop2, -1), count-1)
        }
        if start2 <= stop2, step > 0 {
            let slice = self[start2..<stop2]
            guard step > 0 else { return [] }
            return slice.everyOther(step: step)
        } else if start2 > stop2, step < 0 {
            let slice = self[(stop2+1)...(start2)].reversed().map { $0 }
            guard step < 0 else { return [] }
            return slice.everyOther(step: -step)
        } else {
            return []
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
