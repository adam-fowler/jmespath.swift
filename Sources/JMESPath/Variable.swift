import CoreFoundation
import Foundation

/// Internal representation of a variable
public enum JMESVariable {
    case null
    case string(String)
    case number(NSNumber)
    case boolean(Bool)
    case array([JMESVariable])
    case object(JMESObject)
    case expRef(Ast)

    /// initialize JMESVariable from a swift type
    public init(from any: Any) {
        switch any {
        case let string as String:
            self = .string(string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .boolean(number.boolValue)
            } else {
                self = .number(number)
            }
        case let array as [Any]:
            self = .array(array.map { .init(from: $0)})
        case let set as Set<AnyHashable>:
            self = .array(set.map { .init(from: $0)})
        case let dictionary as [String: Any]:
            self = .object(dictionary)
        default:
            if any is NSNull {
                self = .null
                return
            }
            let mirror = Mirror(reflecting: any)
            guard mirror.children.count > 0 else {
                self = .null
                return
            }
            var object: JMESObject = [:]
            for child in mirror.children {
                guard let label = child.label else {
                    self = .null
                    return
                }
                guard let unwrapValue = unwrap(child.value) else {
                    self = .null
                    return
                }
                object[label] = unwrapValue
            }
            self = .object(object)
        }
    }

    /// create JMESVariable from json
    public static func fromJson(_ json: String) throws -> Self {
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8), options: [.allowFragments])
        return JMESVariable(from: object)
    }

    /// Collapse JMESVariable back to its equivalent Swift type
    public func collapse() -> Any? {
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
            return map
        case .expRef:
            return nil
        }
    }

    /// JSON output from variable
    public func json() -> String? {
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
            guard let jsonData = try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed]) else {
                return nil
            }
            return String(decoding: jsonData, as: Unicode.UTF8.self)
        default:
            return nil
        }
    }

    /// JSON type of variable
    public func getType() -> String {
        switch self {
        case .string: return "string"
        case .boolean: return "boolean"
        case .number: return "number"
        case .array: return "array"
        case .object: return "object"
        default: return "null"
        }
    }

    /// Return if two variables are the same type
    public func isSameType(as variable: JMESVariable) -> Bool {
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

    /// Get variable for field from object type
    public func getField(_ key: String) -> JMESVariable {
        if case .object(let object) = self {
            return object[key].map { JMESVariable(from: $0)} ?? .null
        }
        return .null
    }

    /// Get variable for index from array type
    public func getIndex(_ index: Int) -> JMESVariable {
        if case .array(let array) = self {
            let index = array.calculateIndex(index)
            if index >= 0, index < array.count {
                return array[index]
            }
        }
        return .null
    }

    public func isTruthy() -> Bool {
        switch self {
        case .boolean(let bool): return bool
        case .string(let string): return !string.isEmpty
        case .array(let array): return !array.isEmpty
        case .object(let object): return !object.isEmpty
        case .number: return true
        default: return false
        }
    }

    public func compare(_ comparator: Comparator, value: JMESVariable) -> Bool? {
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
}

extension JMESVariable: Equatable {
    public static func == (lhs: JMESVariable, rhs: JMESVariable) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null):
            return true
        case (.string(let lhs), .string(let rhs)):
            return lhs == rhs
        case (.boolean(let lhs), .boolean(let rhs)):
            return lhs == rhs
        case (.number(let lhs), .number(let rhs)):
            return lhs == rhs
        case (.array(let lhs), .array(let rhs)):
            return lhs == rhs
        case (.object(let lhs), .object(let rhs)):
            return lhs == rhs
        case (.expRef(let lhs), .expRef(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

/// unwrap optional
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

    /// Slice implementation
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

public typealias JMESObject = [String: Any]
extension JMESObject {
    static fileprivate func == (_ lhs: JMESObject, _ rhs: JMESObject) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for element in lhs {
            guard let rhsValue = rhs[element.key], JMESVariable(from: rhsValue) == JMESVariable(from: element.value) else  {
                return false
            }
        }
        return true
    }
}
