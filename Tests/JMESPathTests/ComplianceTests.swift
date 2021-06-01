//
//  File.swift
//
//
//  Created by Adam Fowler on 29/05/2021.
//

import Foundation

import Foundation
#if os(Linux)
import FoundationNetworking
#endif
@testable import JMESPath
import XCTest

public struct AnyDecodable: Decodable {
    public let value: Any

    public init<T>(_ value: T) {
        self.value = value
    }
}

public extension AnyDecodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.init(NSNull())
        } else if let bool = try? container.decode(Bool.self) {
            self.init(bool)
        } else if let int = try? container.decode(Int.self) {
            self.init(int)
        } else if let uint = try? container.decode(UInt.self) {
            self.init(uint)
        } else if let double = try? container.decode(Double.self) {
            self.init(double)
        } else if let string = try? container.decode(String.self) {
            self.init(string)
        } else if let array = try? container.decode([AnyDecodable].self) {
            self.init(array.map(\.value))
        } else if let dictionary = try? container.decode([String: AnyDecodable].self) {
            self.init(dictionary.mapValues { $0.value })
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyDecodable value cannot be decoded")
        }
    }
}

/// Verify implementation against formal standard for Mustache.
/// https://github.com/mustache/spec
final class ComplianceTests: XCTestCase {
    struct ComplianceTest: Decodable {
        struct Case: Decodable {
            let expression: String
            let error: String?
            let bench: String?
            let result: AnyDecodable?
            let comment: String?
        }

        let given: AnyDecodable
        let cases: [Case]
        let comment: String?

        func run() throws {
            for c in self.cases {
                if let _ = c.bench {
                    testBenchmark(c)
                } else if let error = c.error {
                    testError(c, error: error)
                } else {
                    testResult(c, result: c.result?.value)
                }
            }
        }
        
        func testBenchmark(_ c: Case) {
            do {
                let expression = try Expression.compile(c.expression)
                _ = try expression.search(self.given.value)
            } catch {
                XCTFail("\(error)")
            }
        }

        func testError(_ c: Case, error: String) {
            do {
                let expression = try Expression.compile(c.expression)
                _ = try expression.search(self.given.value)
            } catch {
                return
            }
            if let comment = c.comment {
                print("Test: \(comment)")
            }
            print("Expression: \(c.expression)")
            XCTFail("Should throw an error")
        }

        func testResult(_ c: Case, result: Any?) {
            do {
                let expression = try Expression.compile(c.expression)
                
                let resultJson: String? = try result.map {
                    let data = try JSONSerialization.data(withJSONObject: $0, options: [.fragmentsAllowed, .sortedKeys])
                    return String(decoding: data, as: Unicode.UTF8.self)
                }
                if let value = try expression.search(self.given.value) {
                    let valueData = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
                    let valueJson = String(decoding: valueData, as: Unicode.UTF8.self)
                    XCTAssertEqual(resultJson, valueJson)
                } else {
                    XCTAssertNil(result)
                }
            } catch {
                XCTFail("\(error)")
            }
        }
        
        func output(_ c: Case, expected: String?, result: String?) {
            if expected != result {
                let data = try! JSONSerialization.data(withJSONObject: self.given.value, options: [.fragmentsAllowed, .sortedKeys])
                let givenJson = String(decoding: data, as: Unicode.UTF8.self)
                if let comment = c.comment {
                    print("Comment: \(comment)")
                }
                print("Expression: \(c.expression)")
                print("Given: \(givenJson)")
                print("Expected: \(expected ?? "nil")")
                print("Result: \(result ?? "nil")")

            }
        }
    }

    func testCompliance(name: String, ignoring: [String] = []) throws {
        let url = URL(string: "https://raw.githubusercontent.com/jmespath/jmespath.test/master/tests/\(name).json")!
        try testCompliance(url: url, ignoring: ignoring)
    }

    func testCompliance(url: URL, ignoring: [String] = []) throws {
        let data = try Data(contentsOf: url)
        let tests = try JSONDecoder().decode([ComplianceTest].self, from: data)

        for test in tests {
            try test.run()
        }
    }

    func testBasic() throws {
        try self.testCompliance(name: "basic")
    }

    func testBenchmarks() throws {
        try self.testCompliance(name: "benchmarks")
    }

    func testBoolean() throws {
        try self.testCompliance(name: "boolean")
    }

    func testCurrent() throws {
        try self.testCompliance(name: "current")
    }

    func testEscape() throws {
        try self.testCompliance(name: "escape")
    }

    func testFilters() throws {
        try self.testCompliance(name: "filters")
    }

    func testFunctions() throws {
        try self.testCompliance(name: "functions")
    }

    func testIdentifiers() throws {
        try self.testCompliance(name: "identifiers")
    }

    func testIndices() throws {
        try self.testCompliance(name: "indices")
    }

    func testLiteral() throws {
        try self.testCompliance(name: "literal")
    }

    func testMultiSelect() throws {
        try self.testCompliance(name: "multiselect")
    }

    func testPipe() throws {
        try self.testCompliance(name: "pipe")
    }

    func testSlice() throws {
        try self.testCompliance(name: "slice")
    }

    func testSyntax() throws {
        try self.testCompliance(name: "syntax")
    }

    func testUnicode() throws {
        try self.testCompliance(name: "unicode")
    }

    func testWildcards() throws {
        try self.testCompliance(name: "wildcard")
    }
    
    func testIndividual() throws {
        let expression = try Expression.compile("*[?[0] == `0`]")
        let result = try expression.search(json: #"{"foo": [0, 1], "bar": [2, 3]}"#)
        print(result ?? "nil")
    }
}
