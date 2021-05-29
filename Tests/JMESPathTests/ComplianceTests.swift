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
            let result: AnyDecodable?
        }

        let given: AnyDecodable
        let cases: [Case]

        func run() throws {
            for c in self.cases {
                do {
                    let expression = try Expression.compile(c.expression)
                    let value = try expression.search(self.given.value)
                    if let result = c.result {
                        let json1 = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
                        let json2 = try JSONSerialization.data(withJSONObject: result.value, options: [.fragmentsAllowed, .sortedKeys])
                        print("Expression: \(c.expression)")
                        print("Given: \(self.given.value)")
                        print("Expected: \(c.result?.value)")
                        print("Result: \(value)")
                        XCTAssertEqual(json1, json2)
                    } else {
                        print("Expression: \(c.expression)")
                        print("Given: \(self.given.value)")
                        print("Expected: \(c.result?.value)")
                        print("Result: \(value)")
                        XCTAssertNil(value)
                    }
                } catch {
                    print("Expression: \(c.expression)")
                    print("Given: \(self.given.value)")
                    print("Expected: \(c.result?.value)")
                    XCTFail("\(error)")
                }
            }
        }
    }

    func testSpec(name: String, ignoring: [String] = []) throws {
        let url = URL(string: "https://raw.githubusercontent.com/jmespath/jmespath.test/master/tests/\(name).json")!
        try testSpec(url: url, ignoring: ignoring)
    }

    func testSpec(url: URL, ignoring: [String] = []) throws {
        let data = try Data(contentsOf: url)
        let tests = try JSONDecoder().decode([ComplianceTest].self, from: data)

        for test in tests {
            try test.run()
        }
    }

    func testBasic() throws {
        try self.testSpec(name: "basic")
    }

    func testBenchmarks() throws {
        try self.testSpec(name: "benchmarks")
    }

    func testBoolean() throws {
        try self.testSpec(name: "boolean")
    }

    func testCurrent() throws {
        try self.testSpec(name: "current")
    }

    func testEscape() throws {
        try self.testSpec(name: "escape")
    }

    func testFilters() throws {
        try self.testSpec(name: "filters")
    }

    func testFunctions() throws {
        try self.testSpec(name: "functions")
    }

    func testIdentifiers() throws {
        try self.testSpec(name: "identifiers")
    }

    func testIndices() throws {
        try self.testSpec(name: "indices")
    }

    func testLiteral() throws {
        try self.testSpec(name: "literal")
    }

    func testMultiSelect() throws {
        try self.testSpec(name: "multiselect")
    }

    func testPipe() throws {
        try self.testSpec(name: "pipe")
    }

    func testSlice() throws {
        try self.testSpec(name: "slice")
    }

    func testSyntax() throws {
        try self.testSpec(name: "syntax")
    }

    func testUnicode() throws {
        try self.testSpec(name: "unicode")
    }

    func testWildcards() throws {
        try self.testSpec(name: "wildcard")
    }

    func testIndividual() throws {
        let expression = try Expression.compile("EmptyList && False")
        let value = try expression.search(["True": true, "Zero": 0, "False": false, "Number": 5, "EmptyList": []])
        print(value)
    }
}
