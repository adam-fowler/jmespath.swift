import Foundation

public indirect enum FunctionArgumentType {
    case any
    case null
    case string
    case number
    case boolean
    case object
    case array
    case expRef
    case typedArray(FunctionArgumentType)
    case union([FunctionArgumentType])
}

extension JMESVariable {
    func isType(_ type: FunctionArgumentType) -> Bool {
        switch (self, type) {
        case (_, .any),
             (.string, .string),
             (.null, .null),
             (.number, .number),
             (.boolean, .boolean),
             (.array, .array),
             (.object, .object),
             (.expRef, .expRef):
            return true

        case (.array(let array), .typedArray(let elementType)):
            let childElementsAreType = (array.first { !$0.isType(elementType) } == nil)
            return childElementsAreType

        case (_, .union(let types)):
            let isType = types.first { self.isType($0) } != nil
            return isType

        default:
            return false
        }
    }
}

public struct FunctionSignature {
    let inputs: [FunctionArgumentType]
    let varArg: FunctionArgumentType?

    init(inputs: FunctionArgumentType..., varArg: FunctionArgumentType? = nil) {
        self.inputs = inputs
        self.varArg = varArg
    }

    func validateArgs(_ args: [JMESVariable]) throws {
        guard args.count == self.inputs.count ||
            (args.count > self.inputs.count && self.varArg != nil) else {
            throw JMESPathError.runtime("Invalid number of arguments")
        }

        for i in 0..<self.inputs.count {
            guard args[i].isType(self.inputs[i]) else {
                throw JMESPathError.runtime("Invalid argument type")
            }
        }
        if args.count > self.inputs.count {
            for i in self.inputs.count..<args.count {
                guard args[i].isType(self.varArg!) else {
                    throw JMESPathError.runtime("Invalid variadic argument type")
                }
            }
        }
    }
}

protocol Function {
    static var signature: FunctionSignature { get }
    static func evaluate(args: [JMESVariable], runtime: Runtime) throws -> JMESVariable
}

protocol NumberFunction: Function {
    static func evaluate(_ number: NSNumber) -> JMESVariable
}

extension NumberFunction {
    static var signature: FunctionSignature { .init(inputs: .number) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch args[0] {
        case .number(let number):
            return self.evaluate(number)
        default:
            preconditionFailure()
        }
    }
}

protocol ArrayFunction: Function {
    static func evaluate(_ array: [JMESVariable]) -> JMESVariable
}

extension ArrayFunction {
    static var signature: FunctionSignature { .init(inputs: .array) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch args[0] {
        case .array(let array):
            return self.evaluate(array)
        default:
            preconditionFailure()
        }
    }
}

struct AbsFunction: NumberFunction {
    static func evaluate(_ number: NSNumber) -> JMESVariable {
        return .number(.init(value: abs(number.doubleValue)))
    }
}

struct AvgFunction: ArrayFunction {
    static var signature: FunctionSignature { .init(inputs: .typedArray(.number)) }
    static func evaluate(_ array: [JMESVariable]) -> JMESVariable {
        guard array.count > 0 else { return .null }
        let total = array.reduce(0.0) {
            if case .number(let number) = $1 {
                return $0 + number.doubleValue
            } else {
                preconditionFailure()
            }
        }
        return .number(.init(value: total / Double(array.count)))
    }
}

struct CeilFunction: NumberFunction {
    static func evaluate(_ number: NSNumber) -> JMESVariable {
        return .number(.init(value: ceil(number.doubleValue)))
    }
}

struct ContainsFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .union([.array, .string]), .any) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch (args[0], args[1]) {
        case (.array(let array), _):
            let result = array.firstIndex(of: args[1]) != nil
            return .boolean(result)

        case (.string(let string), .string(let string2)):
            let result = string.contains(string2)
            return .boolean(result)

        case (.string, _):
            return .null

        default:
            preconditionFailure()
        }
    }
}

struct EndsWithFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .string, .string) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch (args[0], args[1]) {
        case (.string(let string), .string(let string2)):
            return .boolean(string.hasSuffix(string2))
        default:
            preconditionFailure()
        }
    }
}

struct FloorFunction: NumberFunction {
    static func evaluate(_ number: NSNumber) -> JMESVariable {
        return .number(.init(value: floor(number.doubleValue)))
    }
}

struct JoinFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .string, .typedArray(.string)) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch (args[0], args[1]) {
        case (.string(let separator), .array(let array)):
            let strings: [String] = array.map {
                if case .string(let s) = $0 {
                    return s
                } else {
                    preconditionFailure()
                }
            }
            return .string(strings.joined(separator: separator))
        default:
            preconditionFailure()
        }
    }
}

struct KeysFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .object) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch args[0] {
        case .object(let object):
            return .array(object.map { .string($0.key) })
        default:
            preconditionFailure()
        }
    }
}

struct LengthFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .union([.array, .object, .string])) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch args[0] {
        case .array(let array):
            return .number(.init(value: array.count))
        case .object(let object):
            return .number(.init(value: object.count))
        case .string(let string):
            return .number(.init(value: string.count))
        default:
            preconditionFailure()
        }
    }
}

struct MapFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .expRef, .array) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) throws -> JMESVariable {
        switch (args[0], args[1]) {
        case (.expRef(let ast), .array(let array)):
            let results = try array.map { try runtime.interpret($0, ast: ast) }
            return .array(results)
        default:
            preconditionFailure()
        }
    }
}

struct MaxFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .union([.typedArray(.string), .typedArray(.number)])) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch args[0] {
        case .array(let array):
            if array.count == 0 { return .null }
            switch array[0] {
            case .string(var max):
                for element in array.dropFirst() {
                    if case .string(let string) = element {
                        if string > max {
                            max = string
                        }
                    }
                }
                return .string(max)

            case .number(var max):
                for element in array.dropFirst() {
                    if case .number(let number) = element {
                        if number.compare(max) == .orderedDescending {
                            max = number
                        }
                    }
                }
                return .number(max)

            default:
                preconditionFailure()
            }

        default:
            preconditionFailure()
        }
    }
}

struct MaxByFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .array, .expRef) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) throws -> JMESVariable {
        switch (args[0], args[1]) {
        case (.array(let array), .expRef(let ast)):
            if array.count == 0 { return .null }
            let firstValue = try runtime.interpret(array.first!, ast: ast)
            var maxElement: JMESVariable = array.first!
            switch firstValue {
            case .string(var maxValue):
                for element in array.dropFirst() {
                    let value = try runtime.interpret(element, ast: ast)
                    if case .string(let string) = value {
                        if string > maxValue {
                            maxValue = string
                            maxElement = element
                        }
                    } else {
                        throw JMESPathError.runtime("Invalid argment")
                    }
                }
                return maxElement

            case .number(var maxValue):
                for element in array.dropFirst() {
                    let value = try runtime.interpret(element, ast: ast)
                    if case .number(let number) = value {
                        if number.compare(maxValue) == .orderedDescending {
                            maxValue = number
                            maxElement = element
                        }
                    } else {
                        throw JMESPathError.runtime("Invalid argment")
                    }
                }
                return maxElement

            default:
                throw JMESPathError.runtime("Invalid argment")
            }
        default:
            preconditionFailure()
        }
    }
}

struct MinFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .union([.typedArray(.string), .typedArray(.number)])) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch args[0] {
        case .array(let array):
            if array.count == 0 { return .null }
            switch array[0] {
            case .string(var min):
                for element in array {
                    if case .string(let string) = element {
                        if string < min {
                            min = string
                        }
                    }
                }
                return .string(min)

            case .number(var min):
                for element in array {
                    if case .number(let number) = element {
                        if number.compare(min) == .orderedAscending {
                            min = number
                        }
                    }
                }
                return .number(min)

            default:
                preconditionFailure()
            }

        default:
            preconditionFailure()
        }
    }
}

struct MinByFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .array, .expRef) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) throws -> JMESVariable {
        switch (args[0], args[1]) {
        case (.array(let array), .expRef(let ast)):
            if array.count == 0 { return .null }
            let firstValue = try runtime.interpret(array.first!, ast: ast)
            var minElement: JMESVariable = array.first!
            switch firstValue {
            case .string(var minValue):
                for element in array.dropFirst() {
                    let value = try runtime.interpret(element, ast: ast)
                    if case .string(let string) = value {
                        if string < minValue {
                            minValue = string
                            minElement = element
                        }
                    } else {
                        throw JMESPathError.runtime("Invalid argment")
                    }
                }
                return minElement

            case .number(var minValue):
                for element in array.dropFirst() {
                    let value = try runtime.interpret(element, ast: ast)
                    if case .number(let number) = value {
                        if number.compare(minValue) == .orderedAscending {
                            minValue = number
                            minElement = element
                        }
                    } else {
                        throw JMESPathError.runtime("Invalid argment")
                    }
                }
                return minElement

            default:
                throw JMESPathError.runtime("Invalid argment")
            }
        default:
            preconditionFailure()
        }
    }
}

struct MergeFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .object, varArg: .object) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch args[0] {
        case .object(var object):
            for arg in args.dropFirst() {
                if case .object(let object2) = arg {
                    object = object.merging(object2) { $1 }
                } else {
                    preconditionFailure()
                }
            }
            return .object(object)
        default:
            preconditionFailure()
        }
    }
}

struct NotNullFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .any, varArg: .any) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        for arg in args {
            guard case .null = arg else {
                return arg
            }
        }
        return .null
    }
}

struct ReverseFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .union([.array, .string])) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch args[0] {
        case .string(let string):
            return .string(String(string.reversed()))
        case .array(let array):
            return .array(array.reversed())
        default:
            preconditionFailure()
        }
    }
}

struct SortFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .union([.typedArray(.number), .typedArray(.string)])) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch args[0] {
        case .array(let array):
            return .array(array.sorted { $0.compare(.lessThan, value: $1) == true })
        default:
            preconditionFailure()
        }
    }
}

struct SortByFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .array, .expRef) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) throws -> JMESVariable {
        struct ValueAndSortKey {
            let value: JMESVariable
            let sortValue: JMESVariable
        }
        switch (args[0], args[1]) {
        case (.array(let array), .expRef(let ast)):
            guard let first = array.first else { return .array(array) }
            let firstSortValue = try runtime.interpret(first, ast: ast)
            switch firstSortValue {
            case .string, .number:
                break
            default:
                throw JMESPathError.runtime("Invalid argument for sorting")
            }

            let restOfTheValues = try array.dropFirst().map { element -> ValueAndSortKey in
                let sortValue = try runtime.interpret(element, ast: ast)
                guard sortValue.isSameType(as: firstSortValue) else {
                    throw JMESPathError.runtime("Sort arguments all have to be the same type")
                }
                return .init(value: element, sortValue: sortValue)
            }
            let values = [ValueAndSortKey(value: first, sortValue: firstSortValue)] + restOfTheValues
            let sorted = values.sorted(by: { $0.sortValue.compare(.lessThan, value: $1.sortValue) == true })
            return .array(sorted.map { $0.value} )
        default:
            preconditionFailure()
        }
    }
}

struct StartsWithFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .string, .string) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch (args[0], args[1]) {
        case (.string(let string), .string(let string2)):
            return .boolean(string.hasPrefix(string2))
        default:
            preconditionFailure()
        }
    }
}

struct SumFunction: ArrayFunction {
    static var signature: FunctionSignature { .init(inputs: .typedArray(.number)) }
    static func evaluate(_ array: [JMESVariable]) -> JMESVariable {
        let total = array.reduce(0.0) {
            if case .number(let number) = $1 {
                return $0 + number.doubleValue
            } else {
                preconditionFailure()
            }
        }
        return .number(.init(value: total))
    }
}

struct ToArrayFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .any) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch args[0] {
        case .array(let array):
            return .array(array)
        default:
            return .array([args[0]])
        }
    }
}

struct ToNumberFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .any) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) throws -> JMESVariable {
        switch args[0] {
        case .number(let number):
            return .number(number)
        case .string(let string):
            do {
                let number = try JSONSerialization.jsonObject(with: Data("\(string)".utf8), options: [.allowFragments, .fragmentsAllowed])
                return try JMESVariable(from: number)
            } catch {
                return .null
            }
        default:
            return .null
        }
    }
}

struct ToStringFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .any) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) throws -> JMESVariable {
        switch args[0] {
        case .string(let string):
            return .string(string)
        default:
            return args[0].json().map { .string($0) } ?? .null
        }
    }
}

struct TypeFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .any) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) throws -> JMESVariable {
        return .string(args[0].getType())
    }
}

struct ValuesFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .object) }
    static func evaluate(args: [JMESVariable], runtime: Runtime) -> JMESVariable {
        switch args[0] {
        case .object(let object):
            return .array(object.map { $0.value })
        default:
            preconditionFailure()
        }
    }
}

