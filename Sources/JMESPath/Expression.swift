
public struct Expression {
    let ast: Ast

    public static func compile(_ text: String) throws -> Self {
        let lexer = Lexer(text: text)
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let ast = try parser.parse()
        return self.init(ast)
    }

    public func search(_ any: Any) throws -> Any? {
        let runtime = Runtime()
        return try runtime.interpret(JMESVariable(from: any), ast: self.ast).collapse()
    }

    private init(_ ast: Ast) {
        self.ast = ast
    }
}
