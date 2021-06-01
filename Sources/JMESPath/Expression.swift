import Foundation

/// JMES Expression
///
/// Holds a compiled JMES expression and allows you to search Json text or a type already in memory
public struct Expression {
    let ast: Ast

    public static func compile(_ text: String) throws -> Self {
        let lexer = Lexer(text: text)
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let ast = try parser.parse()
        return self.init(ast)
    }

    /// Search JSON
    ///
    /// - Parameters:
    ///   - any: JSON to search
    ///   - as: Swift type to return
    ///   - runtime: JMES runtime (includes functions)
    /// - Throws: JMESPathError
    /// - Returns: Search result
    public func search<Value>(json: String, as: Value.Type = Value.self, runtime: JMESRuntime = .init()) throws -> Value? {
        return try self.search(json: json, runtime: runtime) as? Value
    }

    /// Search Swift type
    ///
    /// - Parameters:
    ///   - any: Swift type to search
    ///   - as: Swift type to return
    ///   - runtime: JMES runtime (includes functions)
    /// - Throws: JMESPathError
    /// - Returns: Search result
    public func search<Value: RawRepresentable>(json: String, as: Value.Type = Value.self, runtime: JMESRuntime = .init()) throws -> Value? {
        if let rawValue = try self.search(json: json, runtime: runtime) as? Value.RawValue {
            return Value(rawValue: rawValue)
        }
        return nil
    }

    /// Search Swift type
    ///
    /// - Parameters:
    ///   - any: Swift type to search
    ///   - as: Swift type to return
    ///   - runtime: JMES runtime (includes functions)
    /// - Throws: JMESPathError
    /// - Returns: Search result
    public func search<Value>(_ any: Any, as: Value.Type = Value.self, runtime: JMESRuntime = .init()) throws -> Value? {
        return try self.search(any, runtime: runtime) as? Value
    }

    /// Search Swift type
    ///
    /// - Parameters:
    ///   - any: Swift type to search
    ///   - as: Swift type to return
    ///   - runtime: JMES runtime (includes functions)
    /// - Throws: JMESPathError
    /// - Returns: Search result
    public func search<Value: RawRepresentable>(_ any: Any, as: Value.Type = Value.self, runtime: JMESRuntime = .init()) throws -> Value? {
        if let rawValue = try self.search(any, runtime: runtime) as? Value.RawValue {
            return Value(rawValue: rawValue)
        }
        return nil
    }

    /// Search JSON
    ///
    /// - Parameters:
    ///   - any: JSON to search
    ///   - runtime: JMES runtime (includes functions)
    /// - Throws: JMESPathError
    /// - Returns: Search result
    public func search(json: String, runtime: JMESRuntime = .init()) throws -> Any? {
        let value = try JMESVariable.fromJson(json)
        return try runtime.interpret(value, ast: self.ast).collapse()
    }

    /// Search Swift type
    ///
    /// - Parameters:
    ///   - any: Swift type to search
    ///   - runtime: JMES runtime (includes functions)
    /// - Throws: JMESPathError
    /// - Returns: Search result
    public func search(_ any: Any, runtime: JMESRuntime = .init()) throws -> Any? {
        return try runtime.interpret(JMESVariable(from: any), ast: self.ast).collapse()
    }

    private init(_ ast: Ast) {
        self.ast = ast
    }
}
