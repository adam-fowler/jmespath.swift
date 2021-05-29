@testable import JMESPath
import XCTest

final class InterpreterTests: XCTestCase {
    func testInterpreter(_ expression: String, data: Any, result: String) {
        do {
            let expression = try Expression.compile(expression)
            let value = try XCTUnwrap(expression.search(data))
            let json = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
            XCTAssertEqual(String(decoding: json, as: Unicode.UTF8.self), result)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testField() {
        self.testInterpreter("a", data: ["a": 5], result: "5")
        self.testInterpreter("a.b", data: ["a": ["b": 5]], result: "5")
    }

    func testIndex() {
        self.testInterpreter("[2]", data: [1, 2, 3, 4, 5], result: "3")
        self.testInterpreter("[-2]", data: [1, 2, 3, 4, 5], result: "4")
        self.testInterpreter("array[1]", data: ["array": [1, 2, 3, 4, 5]], result: "2")
    }

    func testProjection() {
        self.testInterpreter("array[*]", data: ["array": [1, 2]], result: "[1,2]")
        self.testInterpreter("people[*].first", data: ["people": [["first": "John", "last": "Smith"], ["first": "Joan", "last": "Smyth"]]], result: #"["John","Joan"]"#)
    }

    func testFlatten() {
        self.testInterpreter("array[]", data: ["array": [1, 2]], result: "[1,2]")
    }

    func testSlice() {
        self.testInterpreter("array[2:4]", data: ["array": [0, 1, 2, 3, 4, 5, 6, 7, 8]], result: "[2,3]")
        self.testInterpreter("array[:4]", data: ["array": [0, 1, 2, 3, 4, 5, 6, 7, 8]], result: "[0,1,2,3]")
        self.testInterpreter("array[5:]", data: ["array": [0, 1, 2, 3, 4, 5, 6, 7, 8]], result: "[5,6,7,8]")
        self.testInterpreter("array[6:2:-1]", data: ["array": [0, 1, 2, 3, 4, 5, 6, 7, 8]], result: "[6,5,4,3]")
        self.testInterpreter("array[7:0:-3]", data: ["array": [0, 1, 2, 3, 4, 5, 6, 7, 8]], result: "[7,4,1]")
        self.testInterpreter("array[5::-1]", data: ["array": [0, 1, 2, 3, 4, 5, 6, 7, 8]], result: "[5,4,3,2,1,0]")
    }

    func testFunction() {
        self.testInterpreter("array[?length(@) > `5`]", data: ["array": ["test", "longer"]], result: #"["longer"]"#)
    }

    func testFunctions() {
        self.testInterpreter("abs(number)", data: ["number": -6], result: #"6"#)
        self.testInterpreter("avg(@)", data: [5, 7, 12], result: #"8"#)
        self.testInterpreter("ceil(number)", data: ["number": 6.2], result: #"7"#)
        self.testInterpreter("contains(@, 'test')", data: "testString", result: "true")
        self.testInterpreter("contains(@, `5`)", data: [2, 3, 6, 5], result: "true")
        self.testInterpreter("contains(@, 'test')", data: "string", result: "false")
        self.testInterpreter("ends_with(@, 'ing')", data: "string", result: "true")
        self.testInterpreter("floor(number)", data: ["number": 6.2], result: #"6"#)
        self.testInterpreter("join(',', @)", data: ["one", "two", "three"], result: #""one,two,three""#)
        // testInterpreter("keys(@)", data: ["first":1, "second":2], result: #"["first","second"]"#)
        self.testInterpreter("length(@)", data: ["one", "two", "three"], result: #"3"#)
        self.testInterpreter("map(&length(@), @)", data: ["one", "two", "three"], result: #"[3,3,5]"#)
        self.testInterpreter("max(@)", data: [4, 6, 7, 8, -2], result: #"8"#)
        self.testInterpreter("max_by(@, &age).name", data: [["name": "john", "age": 75], ["name": "jane", "age": 78]], result: #""jane""#)
        self.testInterpreter("min(@)", data: [4, 6, 7, 8, -2], result: #"-2"#)
        self.testInterpreter("merge(a,b)", data: ["a": ["a": 1, "b": 2], "b": ["b": 3, "c": 4]], result: #"{"a":1,"b":3,"c":4}"#)
    }
}
