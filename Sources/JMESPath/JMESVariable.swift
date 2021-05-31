import Foundation

public enum JMESVariable: Equatable {
    case null
    case string(String)
    case number(NSNumber)
    case boolean(Bool)
    case array([JMESVariable])
    case object([String: JMESVariable])
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
                throw JMESPathError.invalidValue("Failed to create variable")
            }
            var dictionary: [String: JMESVariable] = [:]
            for child in mirror.children {
                guard let label = child.label else {
                    throw JMESPathError.invalidValue("Failed to create variable")
                }
                guard let unwrapValue = unwrap(child.value) else {
                    throw JMESPathError.invalidValue("Failed to create variable")
                }
                dictionary[label] = try JMESVariable(from: unwrapValue)
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

    func json() -> String? {
        switch self {
        case .string(let string):
            return string
        case .number(let number):
            return String(describing: number)
        case .boolean(let bool):
            return String(describing: bool)
        case .array(let array):
            let collapsed = array.map { $0.collapse() }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: collapsed, options: [.fragmentsAllowed]) else {
                return nil
            }
            return String(decoding: jsonData, as: Unicode.UTF8.self)
        case .object(let object):
            let collapsed = object.mapValues { $0.collapse() }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: collapsed, options: [.fragmentsAllowed]) else {
                return nil
            }
            return String(decoding: jsonData, as: Unicode.UTF8.self)
        default:
            return nil
        }
    }

    func getType() -> String {
        switch self {
        case .string: return "string"
        case .boolean: return "boolean"
        case .number: return "number"
        case .array: return "array"
        case .object: return "object"
        default: return "null"
        }
    }

    func isSameType(as variable: JMESVariable) -> Bool {
        switch (self, variable) {
        case (.null, .null),
             (.string, .string),
             (.boolean, .boolean),
             (.number, .number),
             (.array, .array),
             (.object, .object),
             (.expRef, .expRef):
            return true
        default:
            return false
        }
    }
    
    func getField(_ key: String) -> JMESVariable {
        if case .object(let object) = self {
            return object[key] ?? .null
        }
        return .null
    }

    func getIndex(_ index: Int) -> JMESVariable {
        if case .array(let array) = self {
            let index = array.calculateIndex(index)
            if index >= 0, index < array.count {
                return array[index]
            }
        }
        return .null
    }

    func slice(start: Int?, stop: Int?, step: Int) -> [JMESVariable]? {
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

    func compare(_ comparator: Comparator, value: JMESVariable) -> Bool? {
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
            if case .string(let lhs) = self, case .string(let rhs) = value {
                switch comparator {
                case .lessThan: return lhs < rhs
                case .lessThanOrEqual: return lhs <= rhs
                case .greaterThan: return lhs > rhs
                case .greaterThanOrEqual: return lhs >= rhs
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
