
extension Runtime {
    func interpret(_ data: JMESVariable, ast: Ast) throws -> JMESVariable {
        switch ast {
        case .field(let name):
            return data.getField(name)

        case .subExpr(let lhs, let rhs):
            let leftResult = try self.interpret(data, ast: lhs)
            return try self.interpret(leftResult, ast: rhs)

        case .identity:
            return data

        case .literal(let value):
            return value

        case .index(let index):
            return data.getIndex(index)

        case .or(let lhs, let rhs):
            let leftResult = try self.interpret(data, ast: lhs)
            if leftResult.isTruthy() {
                return leftResult
            } else {
                return try self.interpret(data, ast: rhs)
            }

        case .and(let lhs, let rhs):
            let leftResult = try self.interpret(data, ast: lhs)
            if !leftResult.isTruthy() {
                return leftResult
            } else {
                return try self.interpret(data, ast: rhs)
            }

        case .not(let node):
            let result = try self.interpret(data, ast: node)
            return .boolean(!result.isTruthy())

        case .condition(let predicate, let then):
            let conditionResult = try self.interpret(data, ast: predicate)
            if conditionResult.isTruthy() {
                return try self.interpret(data, ast: then)
            } else {
                return .null
            }

        case .comparison(let comparator, let lhs, let rhs):
            let leftResult = try self.interpret(data, ast: lhs)
            let rightResult = try self.interpret(data, ast: rhs)
            if let result = leftResult.compare(comparator, value: rightResult) {
                return .boolean(result)
            } else {
                return .null
            }

        case .objectValues(let node):
            let subject = try self.interpret(data, ast: node)
            switch subject {
            case .object(let map):
                return .array(map.values.map { $0 })
            default:
                return .null
            }

        case .projection(let lhs, let rhs):
            let leftResult = try self.interpret(data, ast: lhs)
            if case .array(let array) = leftResult {
                var collected: [JMESVariable] = []
                for element in array {
                    let currentResult = try interpret(element, ast: rhs)
                    if currentResult != .null {
                        collected.append(currentResult)
                    }
                }
                return .array(collected)
            } else {
                return .null
            }

        case .flatten(let node):
            let result = try self.interpret(data, ast: node)
            if case .array(let array) = result {
                var collected: [JMESVariable] = []
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
            var collected: [JMESVariable] = []
            for node in elements {
                collected.append(try self.interpret(data, ast: node))
            }
            return .array(collected)

        case .multiHash(let elements):
            if data == .null {
                return .null
            }
            var collected: [String: JMESVariable] = [:]
            for element in elements {
                let valueResult = try self.interpret(data, ast: element.value)
                collected[element.key] = valueResult
            }
            return .object(collected)

        case .function(let name, let args):
            let argResults = try args.map { try interpret(data, ast: $0) }
            if let function = self.getFunction(name) {
                try function.signature.validateArgs(argResults)
                return try function.evaluate(args: argResults, runtime: self)
            } else {
                throw JMESPathError.runtime("Unknown function name '\(name)'")
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
