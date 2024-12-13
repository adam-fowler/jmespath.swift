import XCTest

@testable import JMESPath

final class JSONTests: XCTestCase {
    func testInterpreter<Value: Equatable>(_ expression: String, json: String, result: Value) {
        do {
            let expression = try JMESExpression.compile(expression)
            let searchResult = try XCTUnwrap(expression.search(json: json))
            guard let value = searchResult as? Value else {
                XCTFail("Expected \(Value.self), instead we got \(type(of: searchResult))")
                return
            }
            XCTAssertEqual(value, result)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testString() {
        self.testInterpreter("s", json: #"{"s": "test"}"#, result: "test")
    }

    func testNumbers() {
        let json = #"{"i": 34, "d": 1.4, "b": true}"#
        self.testInterpreter("i", json: json, result: 34)
        self.testInterpreter("d", json: json, result: 1.4)
        self.testInterpreter("b", json: json, result: true)
    }

    func testArray() {
        let json = #"{"a":[1,2,3,4,5]}"#
        self.testInterpreter("a", json: json, result: [1, 2, 3, 4, 5])
        self.testInterpreter("a[2]", json: json, result: 3)
        self.testInterpreter("a[-2]", json: json, result: 4)
        self.testInterpreter("a[1]", json: json, result: 2)
    }

    func testObjects() {
        let json = #"{"sub": {"a": "hello"}}"#
        self.testInterpreter("sub.a", json: json, result: "hello")
    }
}
