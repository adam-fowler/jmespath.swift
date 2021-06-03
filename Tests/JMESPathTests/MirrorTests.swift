@testable import JMESPath
import XCTest

final class MirrorTests: XCTestCase {
    func testInterpreter<Value: Equatable>(_ expression: String, data: Any, result: Value) {
        do {
            let expression = try Expression.compile(expression)
            let value = try XCTUnwrap(expression.search(data, as: Value.self))
            XCTAssertEqual(value, result)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testString() {
        struct TestString {
            let s: String
        }
        let test = TestString(s: "hello")
        self.testInterpreter("s", data: test, result: "hello")
    }

    func testOptional() {
        struct TestString {
            let s: String?
        }
        let test = TestString(s: "hello")
        self.testInterpreter("s", data: test, result: "hello")
    }

    func testNumbers() {
        struct TestNumbers {
            let i: Int
            let d: Double
            let f: Float
            let b: Bool
        }
        let test = TestNumbers(i: 34, d: 1.4, f: 2.5, b: true)
        self.testInterpreter("i", data: test, result: 34)
        self.testInterpreter("d", data: test, result: 1.4)
        self.testInterpreter("f", data: test, result: 2.5)
        self.testInterpreter("b", data: test, result: true)
    }

    func testArray() {
        struct TestArray {
            let a: [Int]
        }
        let test = TestArray(a: [1, 2, 3, 4, 5])
        self.testInterpreter("a[2]", data: test, result: 3)
        self.testInterpreter("a[-2]", data: test, result: 4)
        self.testInterpreter("a[1]", data: test, result: 2)
    }

    func testObjects() {
        struct TestObject {
            struct TestSubObject {
                let a: String
            }

            let sub: TestSubObject
        }
        let test = TestObject(sub: .init(a: "hello"))
        self.testInterpreter("sub.a", data: test, result: "hello")
    }

    func testEnum() {
        enum TestEnum: String {
            case test1
            case test2
        }
        struct TestObject {
            let e: TestEnum
        }
        let test = TestObject(e: .test2)
        self.testInterpreter("e", data: test, result: TestEnum.test2)
    }
}
