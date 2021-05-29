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

extension Variable {
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

    func validateArgs(_ args: [Variable]) -> Bool {
        var valid = true
        guard args.count == self.inputs.count ||
            (args.count > self.inputs.count && self.varArg != nil) else { return false }

        for i in 0..<self.inputs.count {
            valid = valid && args[i].isType(self.inputs[i])
        }
        if args.count > self.inputs.count {
            for i in self.inputs.count..<args.count {
                valid = valid && args[i].isType(self.varArg!)
            }
        }
        return valid
    }
}

protocol Function {
    static var signature: FunctionSignature { get }
    static func evaluate(args: [Variable], runtime: Runtime) -> Variable
}

protocol NumberFunction: Function {
    static func evaluate(_ number: NSNumber) -> Variable
}

extension NumberFunction {
    static var signature: FunctionSignature { .init(inputs: .number) }
    static func evaluate(args: [Variable], runtime: Runtime) -> Variable {
        switch args[0] {
        case .number(let number):
            return self.evaluate(number)
        default:
            preconditionFailure()
        }
    }
}

protocol ArrayFunction: Function {
    static func evaluate(_ array: [Variable]) -> Variable
}

extension ArrayFunction {
    static var signature: FunctionSignature { .init(inputs: .array) }
    static func evaluate(args: [Variable], runtime: Runtime) -> Variable {
        switch args[0] {
        case .array(let array):
            return self.evaluate(array)
        default:
            preconditionFailure()
        }
    }
}

struct AbsFunction: NumberFunction {
    static func evaluate(_ number: NSNumber) -> Variable {
        return .number(.init(value: abs(number.doubleValue)))
    }
}

struct AvgFunction: ArrayFunction {
    static var signature: FunctionSignature { .init(inputs: .typedArray(.number)) }
    static func evaluate(_ array: [Variable]) -> Variable {
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
    static func evaluate(_ number: NSNumber) -> Variable {
        return .number(.init(value: ceil(number.doubleValue)))
    }
}

struct ContainsFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .union([.array, .string]), .any) }
    static func evaluate(args: [Variable], runtime: Runtime) -> Variable {
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
    static func evaluate(args: [Variable], runtime: Runtime) -> Variable {
        switch (args[0], args[1]) {
        case (.string(let string), .string(let string2)):
            return .boolean(string.hasSuffix(string2))
        default:
            preconditionFailure()
        }
    }
}

struct FloorFunction: NumberFunction {
    static func evaluate(_ number: NSNumber) -> Variable {
        return .number(.init(value: floor(number.doubleValue)))
    }
}

struct JoinFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .string, .typedArray(.string)) }
    static func evaluate(args: [Variable], runtime: Runtime) -> Variable {
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
    static func evaluate(args: [Variable], runtime: Runtime) -> Variable {
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
    static func evaluate(args: [Variable], runtime: Runtime) -> Variable {
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
    static func evaluate(args: [Variable], runtime: Runtime) -> Variable {
        switch (args[0], args[1]) {
        case (.expRef(let ast), .array(let array)):
            let results = array.map { runtime.interpret($0, ast: ast) }
            return .array(results)
        default:
            preconditionFailure()
        }
    }
}

struct MaxFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .union([.typedArray(.string), .typedArray(.number)])) }
    static func evaluate(args: [Variable], runtime: Runtime) -> Variable {
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
    static func evaluate(args: [Variable], runtime: Runtime) -> Variable {
        switch (args[0], args[1]) {
        case (.array(let array), .expRef(let ast)):
            if array.count == 0 { return .null }
            let firstValue = runtime.interpret(array.first!, ast: ast)
            var maxElement: Variable = array.first!
            switch firstValue {
            case .string(var maxValue):
                for element in array.dropFirst() {
                    let value = runtime.interpret(element, ast: ast)
                    if case .string(let string) = value {
                        if string > maxValue {
                            maxValue = string
                            maxElement = element
                        }
                    }
                }
                return maxElement

            case .number(var maxValue):
                for element in array.dropFirst() {
                    let value = runtime.interpret(element, ast: ast)
                    if case .number(let number) = value {
                        if number.compare(maxValue) == .orderedDescending {
                            maxValue = number
                            maxElement = element
                        }
                    }
                }
                return maxElement

            default:
                return .null
            }
        default:
            preconditionFailure()
        }
    }
}

struct MinFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .union([.typedArray(.string), .typedArray(.number)])) }
    static func evaluate(args: [Variable], runtime: Runtime) -> Variable {
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
    static func evaluate(args: [Variable], runtime: Runtime) -> Variable {
        switch (args[0], args[1]) {
        case (.array(let array), .expRef(let ast)):
            if array.count == 0 { return .null }
            let firstValue = runtime.interpret(array.first!, ast: ast)
            var minElement: Variable = array.first!
            switch firstValue {
            case .string(var minValue):
                for element in array.dropFirst() {
                    let value = runtime.interpret(element, ast: ast)
                    if case .string(let string) = value {
                        if string > minValue {
                            minValue = string
                            minElement = element
                        }
                    }
                }
                return minElement

            case .number(var minValue):
                for element in array.dropFirst() {
                    let value = runtime.interpret(element, ast: ast)
                    if case .number(let number) = value {
                        if number.compare(minValue) == .orderedDescending {
                            minValue = number
                            minElement = element
                        }
                    }
                }
                return minElement

            default:
                return .null
            }
        default:
            preconditionFailure()
        }
    }
}

struct MergeFunction: Function {
    static var signature: FunctionSignature { .init(inputs: .object, varArg: .object) }
    static func evaluate(args: [Variable], runtime: Runtime) -> Variable {
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
