/// JMES expression abstract syntax tree
indirect enum Ast: Equatable {
    /// compares two nodes using a comparator
    case comparison(comparator: Comparator, lhs: Ast, rhs: Ast)
    /// if `predicate` evaluates to a truthy value returns result from `then`
    case condition(predicate: Ast, then: Ast)
    /// returns the current node
    case identity
    /// used by functions to dynamically evaluate argument values
    case expRef(ast: Ast)
    /// evaluates nodes and then flattens it one level
    case flatten(node: Ast)
    /// function name and a vector of function argument expressions
    case function(name: String, args: [Ast])
    /// extracts a key value from an object
    case field(name: String)
    /// extracts an indexed value from an array
    case index(index: Int)
    /// resolves to a literal value
    case literal(value: JMESVariable)
    /// resolves to a list of evaluated expressions
    case multiList(elements: [Ast])
    /// resolves to a map of key/evaluated expression pairs
    case multiHash(elements: [String: Ast])
    /// evaluates to true/false based on expression
    case not(node: Ast)
    /// evalutes `lhs` and pushes each value through to `rhs`
    case projection(lhs: Ast, rhs: Ast)
    /// evaluates expression and if result is an object then return array of its values
    case objectValues(node: Ast)
    /// evaluates `lhs` and if not truthy returns, otherwise evaluates `rhs`
    case and(lhs: Ast, rhs: Ast)
    /// evaluates `lhs` and if truthy returns, otherwise evaluates `rhs`
    case or(lhs: Ast, rhs: Ast)
    /// returns a slice of an array
    case slice(start: Int?, stop: Int?, step: Int)
    /// evalutes `lhs` and then provides that value to `rhs`
    case subExpr(lhs: Ast, rhs: Ast)
}

/// Comparator used in comparison AST nodes
public enum Comparator: Equatable, JMESSendable {
    case equal
    case notEqual
    case lessThan
    case lessThanOrEqual
    case greaterThan
    case greaterThanOrEqual

    /// initialise `Comparator` from `Token`
    init(from token: Token) throws {
        switch token {
        case .equals: self = .equal
        case .notEqual: self = .notEqual
        case .lessThan: self = .lessThan
        case .lessThanOrEqual: self = .lessThanOrEqual
        case .greaterThan: self = .greaterThan
        case .greaterThanOrEqual: self = .greaterThanOrEqual
        default:
            throw JMESPathError.compileTime("Failed to parse comparison symbol")
        }
    }
}

#if compiler(>=5.6)
// have to force Sendable conformance as enum `.literal` uses `JMESVariable` which
// is not necessarily sendable but in the use here it is
extension Ast: @unchecked Sendable {}
#endif
