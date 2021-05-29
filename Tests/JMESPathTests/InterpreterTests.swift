import XCTest
@testable import JMESPath

final class InterpreterTests: XCTestCase {
    func testInterpreter(_ expression: String, data: Any, result: String) {
        do {
            let expression = try Expression.compile(expression)
            let value = try XCTUnwrap(expression.search(data))
            let json = try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
            XCTAssertEqual(String(decoding: json, as: Unicode.UTF8.self), result)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testField() {
        testInterpreter("a", data: ["a": 5], result: "5")
        testInterpreter("a.b", data: ["a": ["b": 5]], result: "5")
    }

    func testIndex() {
        testInterpreter("[2]", data: [1,2,3,4,5], result: "3")
        testInterpreter("[-2]", data: [1,2,3,4,5], result: "4")
        testInterpreter("array[1]", data: ["array": [1,2,3,4,5]], result: "2")
    }

    func testProjection() {
        testInterpreter("array[*]", data: ["array": [1,2]], result: "[1,2]")
        testInterpreter("people[*].first", data: ["people": [["first": "John", "last": "Smith"], ["first": "Joan", "last": "Smyth"]]], result: #"["John","Joan"]"#)
    }

    func testFlatten() {
        testInterpreter("array[]", data: ["array": [1,2]], result: "[1,2]")
    }

    func testSlice() {
        testInterpreter("array[2:4]", data: ["array": [0,1,2,3,4,5,6,7,8]], result: "[2,3]")
        testInterpreter("array[:4]", data: ["array": [0,1,2,3,4,5,6,7,8]], result: "[0,1,2,3]")
        testInterpreter("array[5:]", data: ["array": [0,1,2,3,4,5,6,7,8]], result: "[5,6,7,8]")
        testInterpreter("array[6:2:-1]", data: ["array": [0,1,2,3,4,5,6,7,8]], result: "[6,5,4,3]")
        testInterpreter("array[7:0:-3]", data: ["array": [0,1,2,3,4,5,6,7,8]], result: "[7,4,1]")
        testInterpreter("array[5::-1]", data: ["array": [0,1,2,3,4,5,6,7,8]], result: "[5,4,3,2,1,0]")
    }
}
