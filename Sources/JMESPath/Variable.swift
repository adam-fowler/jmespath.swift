import Foundation

public typealias JMESArray = [Any]
public typealias JMESObject = [String: Any]

public protocol JMESPropertyWrapper {
    var anyValue: Any { get }
}

/// Internal representation of a variable
public enum JMESVariable {
    case null
    case string(String)
    case number(NSNumber)
    case boolean(Bool)
    case array(JMESArray)
    case object(JMESObject)
    case expRef(Ast)
    case other(Any)

    /// initialize JMESVariable from a swift type
    public init(from any: Any) {
        switch any {
        case let string as String:
            self = .string(string)
        case let number as NSNumber:
            // both booleans and integer/float point types can be converted to a `NSNumber`
            // We have to check to see the type id to see if it is a boolean
            if UInt8(number.objCType[0]) == UInt8(ascii: "c") {
                self = .boolean(number.boolValue)
            } else {
                self = .number(number)
            }
        case let array as [Any]:
            self = .array(array)
        case let set as Set<AnyHashable>:
            self = .array(set.map { $0 })
        case let dictionary as [String: Any]:
            self = .object(dictionary)
        case is NSNull:
            self = .null
        default:
            // use Mirror to build JMESVariable.object
            let mirror = Mirror(reflecting: any)
            guard mirror.children.count > 0 else {
                self = .other(any)
                return
            }
            switch mirror.displayStyle {
            case .collection:
                let array = mirror.children.map {
                    Self.unwrap($0.value) ?? NSNull()
                }
                self = .array(array)
            case .dictionary:
                var object: JMESObject = [:]
                var index: Int = 0
                while let key = mirror.descendant(index, "key") as? String,
                    let value = mirror.descendant(index, "value")
                {
                    object[key] = Self.unwrap(value) ?? NSNull()
                    index += 1
                }
                self = .object(object)
            default:
                var object: JMESObject = [:]
                for child in mirror.children {
                    guard var label = child.label else {
                        self = .null
                        return
                    }
                    var unwrapValue = Self.unwrap(child.value) ?? NSNull()
                    if let wrapper = unwrapValue as? JMESPropertyWrapper, label.first == "_" {
                        label = String(label.dropFirst())
                        unwrapValue = Self.unwrap(wrapper.anyValue) ?? NSNull()
                    }
                    object[label] = unwrapValue
                }
                self = .object(object)
            }
        }
    }

    /// create JMESVariable from json
    public static func fromJson(_ json: String) throws -> Self {
        return try self.fromJson(Data(json.utf8))
    }

    /// create JMESVariable from json
    public static func fromJson(_ json: Data) throws -> Self {
        let object = try JSONSerialization.jsonObject(with: json, options: [.allowFragments])
        return JMESVariable(from: object)
    }

    /// Collapse JMESVariable back to its equivalent Swift type
    public func collapse() -> Any? {
        switch self {
        case .null: return nil
        case .string(let string): return string
        case .number(let number): return number
        case .boolean(let bool): return bool
        case .array(let array): return array
        case .object(let map): return map
        case .other(let any): return any
        case .expRef: return nil
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
            guard
                let jsonData = try? JSONSerialization.data(
                    withJSONObject: array, options: [.fragmentsAllowed])
            else {
                return nil
            }
            return String(decoding: jsonData, as: Unicode.UTF8.self)
        case .object(let object):
            guard
                let jsonData = try? JSONSerialization.data(
                    withJSONObject: object, options: [.fragmentsAllowed])
            else {
                return nil
            }
            return String(decoding: jsonData, as: Unicode.UTF8.self)
        case .other(let any):
            return String(describing: any)
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
        case .expRef: return "expression"
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
            return object[key].map { JMESVariable(from: $0) } ?? .null
        }
        return .null
    }

    /// Get variable for index from array type
    public func getIndex(_ index: Int) -> JMESVariable {
        if case .array(let array) = self {
            let index = array.calculateIndex(index)
            if index >= 0, index < array.count {
                return JMESVariable(from: array[index])
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

    /// Compare JMESVariable with another using supplied comparator
    /// - Parameters:
    ///   - comparator: Comparison operation
    ///   - value: Other value
    /// - Returns: True/False or nil if variables cannot be compared
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

    /// Generate Array slice if variable is an array
    func slice(start: Int?, stop: Int?, step: Int) -> JMESArray? {
        if case .array(let array) = self, step != 0 {
            var start2 = start.map { array.calculateIndex($0) } ?? (step > 0 ? 0 : array.count - 1)
            var stop2 = stop.map { array.calculateIndex($0) } ?? (step > 0 ? array.count : -1)

            if step > 0 {
                start2 = Swift.min(Swift.max(start2, 0), array.count)
                stop2 = Swift.min(Swift.max(stop2, 0), array.count)
            } else {
                start2 = Swift.min(Swift.max(start2, -1), array.count - 1)
                stop2 = Swift.min(Swift.max(stop2, -1), array.count - 1)
            }
            if start2 <= stop2, step > 0 {
                let slice = array[start2..<stop2]
                guard step > 0 else { return [] }
                return slice.skipElements(step: step)
            } else if start2 > stop2, step < 0 {
                let slice = array[(stop2 + 1)...start2].reversed().map { $0 }
                guard step < 0 else { return [] }
                return slice.skipElements(step: -step)
            } else {
                return []
            }
        }
        return nil
    }

    /// unwrap optional
    private static func unwrap(_ any: Any) -> Any? {
        let mirror = Mirror(reflecting: any)
        guard mirror.displayStyle == .optional else { return any }
        guard let first = mirror.children.first else { return nil }
        return first.value
    }
}

extension JMESVariable: Equatable {
    /// extend JMESVariable to be `Equatable`.  Need to write custom equals function
    /// as it needs the custom `equalTo` functions for arrays and objects
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
            return lhs.equalTo(rhs)
        case (.object(let lhs), .object(let rhs)):
            return lhs.equalTo(rhs)
        case (.expRef(let lhs), .expRef(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

extension JMESArray {
    /// return if arrays are equal by converting entries to `JMESVariable`
    fileprivate func equalTo(_ rhs: JMESArray) -> Bool {
        guard self.count == rhs.count else { return false }
        for i in 0..<self.count {
            guard JMESVariable(from: self[i]) == JMESVariable(from: rhs[i]) else {
                return false
            }
        }
        return true
    }
}

extension JMESObject {
    /// return if objects are equal by converting values to `JMESVariable`
    fileprivate func equalTo(_ rhs: JMESObject) -> Bool {
        guard self.count == rhs.count else { return false }
        for element in self {
            guard let rhsValue = rhs[element.key],
                JMESVariable(from: rhsValue) == JMESVariable(from: element.value)
            else {
                return false
            }
        }
        return true
    }
}

extension Array {
    /// calculate actual index. Negative indices read backwards from end of array
    func calculateIndex(_ index: Int) -> Int {
        if index >= 0 {
            return index
        } else {
            return count + index
        }
    }
}

extension RandomAccessCollection {
    /// return array where we skip so many elements between each entry.
    func skipElements(step: Int) -> [Element] {
        precondition(step > 0, "Cannot have non-zero or negative step")
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
