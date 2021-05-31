import Foundation

/// JMES Expression
///
/// Holds a compiled JMES expression and allows you to search Json text or a structure already in memory
public struct Expression {
    let ast: Ast

    public static func compile(_ text: String) throws -> Self {
        let lexer = Lexer(text: text)
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let ast = try parser.parse()
        return self.init(ast)
    }

    public func search(_ any: Any, runtime: Runtime = .init()) throws -> Any? {
        return try runtime.interpret(JMESVariable(from: any), ast: self.ast).collapse()
    }

    public func search(json: String, runtime: Runtime = .init()) throws -> Any? {
        let value = try JMESVariable.fromJson(json)
        return try runtime.interpret(value, ast: self.ast).collapse()
    }

    public func search<Value>(_ any: Any, as: Value.Type = Value.self, runtime: Runtime = .init()) throws -> Value? {
        return try search(any, runtime: runtime) as? Value
    }

    public func search<Value>(json: String, as: Value.Type = Value.self, runtime: Runtime = .init()) throws -> Value? {
        return try search(json: json, runtime: runtime) as? Value
    }

    private init(_ ast: Ast) {
        self.ast = ast
    }
}
