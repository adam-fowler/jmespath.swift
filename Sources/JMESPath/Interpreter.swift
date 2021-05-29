
extension Runtime {
    func interpret(_ data: Variable, ast: Ast) -> Variable {
        switch ast {
        case .field(let name):
            return data.getField(name)

        case .subExpr(let lhs, let rhs):
            let leftResult = interpret(data, ast: lhs)
            return interpret(leftResult, ast: rhs)

        case .identity:
            return data

        case .literal(let value):
            return value

        case .index(let index):
            return data.getIndex(index)

        case .or(let lhs, let rhs):
            let leftResult = interpret(data, ast: lhs)
            if leftResult.isTruthy() {
                return leftResult
            } else {
                return interpret(data, ast: rhs)
            }

        case .and(let lhs, let rhs):
            let leftResult = interpret(data, ast: lhs)
            if !leftResult.isTruthy() {
                return leftResult
            } else {
                return interpret(data, ast: rhs)
            }

        case .not(let node):
            let result = interpret(data, ast: node)
            return .boolean(!result.isTruthy())

        case .condition(let predicate, let then):
            let conditionResult = interpret(data, ast: predicate)
            if conditionResult.isTruthy() {
                return interpret(data, ast: then)
            } else {
                return .null
            }

        case .comparison(let comparator, let lhs, let rhs):
            let leftResult = interpret(data, ast: lhs)
            let rightResult = interpret(data, ast: rhs)
            if let result = leftResult.compare(comparator, value: rightResult) {
                return .boolean(result)
            } else {
                return .null
            }

        case .objectValues(let node):
            let subject = interpret(data, ast: node)
            switch subject {
            case .object(let map):
                return .array(map.values.map { $0 })
            default:
                return .null
            }

        case .projection(let lhs, let rhs):
            let leftResult = interpret(data, ast: lhs)
            if case .array(let array) = leftResult {
                var collected: [Variable] = []
                for element in array {
                    let currentResult = interpret(element, ast: rhs)
                    if currentResult != .null {
                        collected.append(currentResult)
                    }
                }
                return .array(collected)
            } else {
                return .null
            }

        case .flatten(let node):
            let result = interpret(data, ast: node)
            if case .array(let array) = result {
                var collected: [Variable] = []
                for element in array {
                    if case .array(let array2) = element {
                        collected += array2
                    } else {
                        collected.append(element)
                    }
                }
                return .array(collected)
            } else {
                return .null
            }

        case .multiList(let elements):
            if data == .null {
                return .null
            }
            var collected: [Variable] = []
            for node in elements {
                collected.append(interpret(data, ast: node))
            }
            return .array(collected)

        case .multiHash(let elements):
            if data == .null {
                return .null
            }
            var collected: [String: Variable] = [:]
            for element in elements {
                let valueResult = interpret(data, ast: element.value)
                collected[element.key] = valueResult
            }
            return .object(collected)

        case .function(let name, let args):
            let argResults = args.map { interpret(data, ast: $0) }
            if let function = self.getFunction(name) {
                guard function.signature.validateArgs(argResults) else { return .null }
                return function.evaluate(args: argResults, runtime: self)
            } else {
                return .null
            }

        case .expRef(let ast):
            return .expRef(ast)

        case .slice(let start, let stop, let step):
            if let slice = data.slice(start: start, stop: stop, step: step) {
                return .array(slice)
            } else {
                return .null
            }
        }
    }
}
