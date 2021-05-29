import XCTest
@testable import JMESPath

final class LexerTests: XCTestCase {
    func XCTAssertLexerEqual(_ string: String, _ tokens: [Token]) {
        var result: [Token] = []
        XCTAssertNoThrow(result = try Lexer(text: string).tokenize())
        XCTAssertEqual(result, tokens)
    }

    func XCTAssertLexerError(_ string: String, _ expectedError: JMESError) {
        XCTAssertThrowsError(try Lexer(text: string).tokenize()) { error in
            switch error {
            case let jmesError as JMESError where jmesError == expectedError:
                break
            default:
                XCTFail("\(error)")
            }
        }

    }
    
    func testBasic() {
        XCTAssertLexerEqual(".", [.dot, .eof])
        XCTAssertLexerEqual("*", [.star, .eof])
        XCTAssertLexerEqual("@", [.at, .eof])
        XCTAssertLexerEqual("]", [.rightBracket, .eof])
        XCTAssertLexerEqual("{", [.leftBrace, .eof])
        XCTAssertLexerEqual("}", [.rightBrace, .eof])
        XCTAssertLexerEqual("(", [.leftParenthesis, .eof])
        XCTAssertLexerEqual(")", [.rightParenthesis, .eof])
        XCTAssertLexerEqual(",", [.comma, .eof])
    }

    func testLeftBracket() {
        XCTAssertLexerEqual("[", [.leftBracket, .eof])
        XCTAssertLexerEqual("[]", [.flatten, .eof])
        XCTAssertLexerEqual("[?", [.filter, .eof])
    }

    func testPipe() {
        XCTAssertLexerEqual("|", [.pipe, .eof])
        XCTAssertLexerEqual("||", [.or, .eof])
    }

    func testAmpersand() {
        XCTAssertLexerEqual("&", [.ampersand, .eof])
        XCTAssertLexerEqual("&&", [.and, .eof])
    }

    func testLessThanGreaterThan() {
        XCTAssertLexerEqual("<", [.lessThan, .eof])
        XCTAssertLexerEqual("<=", [.lessThanOrEqual, .eof])
        XCTAssertLexerEqual(">", [.greaterThan, .eof])
        XCTAssertLexerEqual(">=", [.greaterThanOrEqual, .eof])
    }

    func testNotEqual() {
        XCTAssertLexerEqual("!", [.not, .eof])
        XCTAssertLexerEqual("!=", [.notEqual, .eof])
    }

    func testInvalidEqual() {
        XCTAssertLexerError("=", .unexpectedCharacter)
    }

    func testInvalidCharacter() {
        XCTAssertLexerError("~", .invalidCharacter)
    }

    func testWhitespace() {
        XCTAssertLexerEqual(" \t\n\r\t. (", [.dot, .leftParenthesis, .eof])
    }

    func testUnclosedError() {
        XCTAssertLexerError("\"foo", .unclosedDelimiter)
    }

    func testIdentifier() {
        XCTAssertLexerEqual("foo_bar", [.identifier("foo_bar"), .eof])
        XCTAssertLexerEqual("a", [.identifier("a"), .eof])
        XCTAssertLexerEqual("a12", [.identifier("a12"), .eof])
        XCTAssertLexerEqual("_a", [.identifier("_a"), .eof])
    }

    func testQuotedIdentifier() {
        XCTAssertLexerEqual("\"foo\"", [.quotedIdentifier("foo"), .eof])
        XCTAssertLexerEqual("\"\"", [.quotedIdentifier(""), .eof])
        XCTAssertLexerEqual("\"a_b\"", [.quotedIdentifier("a_b"), .eof])
        XCTAssertLexerEqual("\"a\\nb\"", [.quotedIdentifier("a\nb"), .eof])
        XCTAssertLexerEqual("\"a\\\\nb\"", [.quotedIdentifier("a\\nb"), .eof])
    }

    func testRawString() throws {
        try XCTAssertLexerEqual("'foo'", [.literal(Variable(from: "foo")), .eof])
        try XCTAssertLexerEqual("''", [.literal(Variable(from: "")), .eof])
        try XCTAssertLexerEqual("'a\\nb'", [.literal(Variable(from: "a\\nb")), .eof])
    }

    func testLiteral() throws {
        XCTAssertLexerError("`a`", JMESError.invalidLiteral)
        try XCTAssertLexerEqual("`\"a\"`", [.literal(Variable(from: "a")), .eof])
    }

    func testNumber() {
        XCTAssertLexerEqual("0", [.number(0), .eof])
        XCTAssertLexerEqual("1", [.number(1), .eof])
        XCTAssertLexerEqual("123", [.number(123), .eof])
    }

    func testNegativeNumber() {
        XCTAssertLexerEqual("-10", [.number(-10), .eof])
    }

    func testSuccessive() throws {
        try XCTAssertLexerEqual("foo.bar || `\"a\"` | 10", [.identifier("foo"), .dot, .identifier("bar"), .or, .literal(Variable(from: "a")), .pipe, .number(10), .eof])
    }

    func testSlice() {
        XCTAssertLexerEqual("foo[0::-1]", [.identifier("foo"), .leftBracket, .number(0), .colon, .colon, .number(-1), .rightBracket, .eof])
    }
}
