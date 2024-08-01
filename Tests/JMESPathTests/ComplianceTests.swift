//
//  File.swift
//
//
//  Created by Adam Fowler on 29/05/2021.
//

import Foundation
import XCTest

@testable import JMESPath

#if os(Linux)
    import FoundationNetworking
#endif

public struct AnyDecodable: Decodable {
    public let value: Any

    public init<T>(_ value: T) {
        self.value = value
    }
}

extension AnyDecodable {
    public init(from decoder: Decoder) throws {
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
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "AnyDecodable value cannot be decoded")
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

        @available(iOS 11.0, tvOS 11.0, watchOS 5.0, *)
        func run() throws {
            for c in self.cases {
                if c.bench != nil {
                    self.testBenchmark(c)
                } else if let error = c.error {
                    self.testError(c, error: error)
                } else {
                    self.testResult(c, result: c.result?.value)
                }
            }
        }

        func testBenchmark(_ c: Case) {
            do {
                let expression = try JMESExpression.compile(c.expression)
                _ = try expression.search(object: self.given.value)
            } catch {
                XCTFail("\(error)")
            }
        }

        func testError(_ c: Case, error: String) {
            do {
                let expression = try JMESExpression.compile(c.expression)
                _ = try expression.search(object: self.given.value)
            } catch {
                return
            }
            if let comment = c.comment {
                print("Test: \(comment)")
            }
            print("Expression: \(c.expression)")
            XCTFail("Should throw an error")
        }

        @available(iOS 11.0, tvOS 11.0, watchOS 5.0, *)
        func testResult(_ c: Case, result: Any?) {
            do {
                let expression = try JMESExpression.compile(c.expression)

                let resultJson: String? = try result.map {
                    let data = try JSONSerialization.data(
                        withJSONObject: $0, options: [.fragmentsAllowed, .sortedKeys])
                    return String(decoding: data, as: Unicode.UTF8.self)
                }
                if let value = try expression.search(object: self.given.value) {
                    let valueData = try JSONSerialization.data(
                        withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
                    let valueJson = String(decoding: valueData, as: Unicode.UTF8.self)
                    XCTAssertEqual(resultJson, valueJson)
                } else {
                    XCTAssertNil(result)
                }
            } catch {
                XCTFail("\(error)")
            }
        }

        @available(iOS 11.0, tvOS 11.0, watchOS 5.0, *)
        func output(_ c: Case, expected: String?, result: String?) {
            if expected != result {
                let data = try! JSONSerialization.data(
                    withJSONObject: self.given.value, options: [.fragmentsAllowed, .sortedKeys])
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

    func testCompliance(name: String, ignoring: [String] = []) async throws {
        let url = URL(
            string:
                "https://raw.githubusercontent.com/jmespath/jmespath.test/master/tests/\(name).json"
        )!
        try await testCompliance(url: url, ignoring: ignoring)
    }

    func testCompliance(url: URL, ignoring: [String] = []) async throws {
        #if compiler(>=6.0)
            let (data, _) = try await URLSession.shared.data(from: url, delegate: nil)
        #else
            let data = try Data(contentsOf: url)
        #endif
        let tests = try JSONDecoder().decode([ComplianceTest].self, from: data)

        if #available(iOS 11.0, tvOS 11.0, watchOS 5.0, *) {
            for test in tests {
                try test.run()
            }
        }
    }

    func testBasic() async throws {
        try await self.testCompliance(name: "basic")
    }

    func testBenchmarks() async throws {
        try await self.testCompliance(name: "benchmarks")
    }

    func testBoolean() async throws {
        try await self.testCompliance(name: "boolean")
    }

    func testCurrent() async throws {
        try await self.testCompliance(name: "current")
    }

    func testEscape() async throws {
        try await self.testCompliance(name: "escape")
    }

    func testFilters() async throws {
        try await self.testCompliance(name: "filters")
    }

    func testFunctions() async throws {
        try await self.testCompliance(name: "functions")
    }

    func testIdentifiers() async throws {
        try await self.testCompliance(name: "identifiers")
    }

    func testIndices() async throws {
        try await self.testCompliance(name: "indices")
    }

    func testLiteral() async throws {
        try await self.testCompliance(name: "literal")
    }

    func testMultiSelect() async throws {
        try await self.testCompliance(name: "multiselect")
    }

    func testPipe() async throws {
        try await self.testCompliance(name: "pipe")
    }

    func testSlice() async throws {
        try await self.testCompliance(name: "slice")
    }

    func testSyntax() async throws {
        try await self.testCompliance(name: "syntax")
    }

    func testUnicode() async throws {
        try await self.testCompliance(name: "unicode")
    }

    func testWildcards() async throws {
        try await self.testCompliance(name: "wildcard")
    }
}
