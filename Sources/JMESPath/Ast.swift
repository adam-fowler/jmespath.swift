//
//  File.swift
//
//
//  Created by Adam Fowler on 27/05/2021.
//

indirect enum Ast: Equatable {
    case comparison(comparator: Comparator, lhs: Ast, rhs: Ast)
    case condition(predicate: Ast, then: Ast)
    case identity
    case expRef(ast: Ast)
    case flatten(node: Ast)
    case function(name: String, args: [Ast])
    case field(name: String)
    case index(index: Int)
    case literal(value: JMESVariable)
    case multiList(elements: [Ast])
    case multiHash(elements: [String: Ast])
    case not(node: Ast)
    case projection(lhs: Ast, rhs: Ast)
    case objectValues(node: Ast)
    case and(lhs: Ast, rhs: Ast)
    case or(lhs: Ast, rhs: Ast)
    case slice(start: Int?, stop: Int?, step: Int)
    case subExpr(lhs: Ast, rhs: Ast)
}

enum Comparator: Equatable {
    case equal
    case notEqual
    case lessThan
    case lessThanOrEqual
    case greaterThan
    case greaterThanOrEqual

    init(from token: Token) throws {
        switch token {
        case .equals: self = .equal
        case .notEqual: self = .notEqual
        case .lessThan: self = .lessThan
        case .lessThanOrEqual: self = .lessThanOrEqual
        case .greaterThan: self = .greaterThan
        case .greaterThanOrEqual: self = .greaterThanOrEqual
        default:
            throw JMESPathError.syntaxError("Failed to parse comparison symbol")
        }
    }
}
