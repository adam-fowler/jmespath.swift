@testable import JMESPath
import XCTest

final class ErrorTests: XCTestCase {
    func testUnknownFunction() throws {
        let expression = try Expression.compile("unknown(@)")
        XCTAssertThrowsError(try expression.search(object: "test")) { error in
            switch error {
            case let error as JMESPathError where error == .runtime("Unknown function name 'unknown'"):
                break
            default:
                XCTFail("\(error)")
            }
        }
    }

    func testWrongNumberOfArgs() throws {
        let expression = try Expression.compile("reverse(@, @)")
        XCTAssertThrowsError(try expression.search(object: "test")) { error in
            switch error {
            case let error as JMESPathError where error == .runtime("Invalid number of arguments, expected 1, got 2"):
                break
            default:
                XCTFail("\(error)")
            }
        }
    }

    func testWrongArg() throws {
        let expression = try Expression.compile("sum(@)")
        XCTAssertThrowsError(try expression.search(object: "test")) { error in
            switch error {
            case let error as JMESPathError where error == .runtime("Invalid argument, expected array[number], got string"):
                break
            default:
                XCTFail("\(error)")
            }
        }
    }

    func testWrongVarArg() throws {
        let expression = try Expression.compile("merge(@, i)")
        XCTAssertThrowsError(try expression.search(json: #"{"i": 24}"#)) { error in
            switch error {
            case let error as JMESPathError where error == .runtime("Invalid variadic argument, expected object, got number"):
                break
            default:
                XCTFail("\(error)")
            }
        }
    }

    func testMinByWrongType() throws {
        let expression = try Expression.compile("min_by(@, &i)")
        XCTAssertThrowsError(try expression.search(json: #"[{"i": true}]"#)) { error in
            switch error {
            case let error as JMESPathError where error == .runtime("Invalid argment, expected array values to be strings or numbers, instead got boolean"):
                break
            default:
                XCTFail("\(error)")
            }
        }
    }

    func testSortByWrongType() throws {
        let expression = try Expression.compile("sort_by(@, &i)")
        XCTAssertThrowsError(try expression.search(json: #"[{"i": "one"}, {"i": 2}]"#)) { error in
            switch error {
            case let error as JMESPathError where error == .runtime("Sort arguments all have to be the same type, expected string, instead got number"):
                break
            default:
                XCTFail("\(error)")
            }
        }
    }
}
