@testable import JMESPath
import XCTest

final class LexerTests: XCTestCase {
    func XCTAssertLexerEqual(_ string: String, _ tokens: [Token]) {
        var result: [Token] = []
        XCTAssertNoThrow(result = try Lexer(text: string).tokenize())
        XCTAssertEqual(result, tokens)
    }

    func XCTAssertLexerError(_ string: String, _ expectedError: JMESPathError) {
        XCTAssertThrowsError(try Lexer(text: string).tokenize()) { error in
            switch error {
            case let jmesError as JMESPathError where jmesError == expectedError:
                break
            default:
                XCTFail("\(error)")
            }
        }
    }

    func testBasic() {
        self.XCTAssertLexerEqual(".", [.dot, .eof])
        self.XCTAssertLexerEqual("*", [.star, .eof])
        self.XCTAssertLexerEqual("@", [.at, .eof])
        self.XCTAssertLexerEqual("]", [.rightBracket, .eof])
        self.XCTAssertLexerEqual("{", [.leftBrace, .eof])
        self.XCTAssertLexerEqual("}", [.rightBrace, .eof])
        self.XCTAssertLexerEqual("(", [.leftParenthesis, .eof])
        self.XCTAssertLexerEqual(")", [.rightParenthesis, .eof])
        self.XCTAssertLexerEqual(",", [.comma, .eof])
    }

    func testLeftBracket() {
        self.XCTAssertLexerEqual("[", [.leftBracket, .eof])
        self.XCTAssertLexerEqual("[]", [.flatten, .eof])
        self.XCTAssertLexerEqual("[?", [.filter, .eof])
    }

    func testPipe() {
        self.XCTAssertLexerEqual("|", [.pipe, .eof])
        self.XCTAssertLexerEqual("||", [.or, .eof])
    }

    func testAmpersand() {
        self.XCTAssertLexerEqual("&", [.ampersand, .eof])
        self.XCTAssertLexerEqual("&&", [.and, .eof])
    }

    func testLessThanGreaterThan() {
        self.XCTAssertLexerEqual("<", [.lessThan, .eof])
        self.XCTAssertLexerEqual("<=", [.lessThanOrEqual, .eof])
        self.XCTAssertLexerEqual(">", [.greaterThan, .eof])
        self.XCTAssertLexerEqual(">=", [.greaterThanOrEqual, .eof])
    }

    func testNotEqual() {
        self.XCTAssertLexerEqual("!", [.not, .eof])
        self.XCTAssertLexerEqual("!=", [.notEqual, .eof])
    }

    func testInvalidEqual() {
        self.XCTAssertLexerError("=", .compileTime("'=' is not valid, did you mean '=='"))
    }

    func testInvalidCharacter() {
        self.XCTAssertLexerError("~", .compileTime("Unable to parse character '~'"))
    }

    func testWhitespace() {
        self.XCTAssertLexerEqual(" \t\n\r\t. (", [.dot, .leftParenthesis, .eof])
    }

    func testUnclosedError() {
        self.XCTAssertLexerError("\"foo", .compileTime("Unclosed \" delimiter"))
    }

    func testIdentifier() {
        self.XCTAssertLexerEqual("foo_bar", [.identifier("foo_bar"), .eof])
        self.XCTAssertLexerEqual("a", [.identifier("a"), .eof])
        self.XCTAssertLexerEqual("a12", [.identifier("a12"), .eof])
        self.XCTAssertLexerEqual("_a", [.identifier("_a"), .eof])
    }

    func testQuotedIdentifier() {
        self.XCTAssertLexerEqual("\"foo\"", [.quotedIdentifier("foo"), .eof])
        self.XCTAssertLexerEqual("\"\"", [.quotedIdentifier(""), .eof])
        self.XCTAssertLexerEqual("\"a_b\"", [.quotedIdentifier("a_b"), .eof])
        self.XCTAssertLexerEqual("\"a\\nb\"", [.quotedIdentifier("a\nb"), .eof])
        self.XCTAssertLexerEqual("\"a\\\\nb\"", [.quotedIdentifier("a\\nb"), .eof])
    }

    func testRawString() throws {
        self.XCTAssertLexerEqual("'foo'", [.literal(JMESVariable(from: "foo")), .eof])
        self.XCTAssertLexerEqual("''", [.literal(JMESVariable(from: "")), .eof])
        self.XCTAssertLexerEqual("'a\\nb'", [.literal(JMESVariable(from: "a\\nb")), .eof])
    }

    func testLiteral() throws {
        self.XCTAssertLexerError("`a`", JMESPathError.compileTime("Unable to parse literal JSON"))
        self.XCTAssertLexerEqual("`\"a\"`", [.literal(JMESVariable(from: "a")), .eof])
    }

    func testNumber() {
        self.XCTAssertLexerEqual("0", [.number(0), .eof])
        self.XCTAssertLexerEqual("1", [.number(1), .eof])
        self.XCTAssertLexerEqual("123", [.number(123), .eof])
    }

    func testNegativeNumber() {
        self.XCTAssertLexerEqual("-10", [.number(-10), .eof])
    }

    func testSuccessive() throws {
        self.XCTAssertLexerEqual("foo.bar || `\"a\"` | 10", [.identifier("foo"), .dot, .identifier("bar"), .or, .literal(JMESVariable(from: "a")), .pipe, .number(10), .eof])
    }

    func testSlice() {
        self.XCTAssertLexerEqual("foo[0::-1]", [.identifier("foo"), .leftBracket, .number(0), .colon, .colon, .number(-1), .rightBracket, .eof])
    }
}
