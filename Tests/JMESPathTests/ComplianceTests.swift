//
//  File.swift
//
//
//  Created by Adam Fowler on 29/05/2021.
//

import Foundation
import JMESPath
import XCTest

#if os(Linux) || os(Windows)
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
                in: container,
                debugDescription: "AnyDecodable value cannot be decoded"
            )
        }
    }
}

/// Verify implementation against formal standard for Mustache.
/// https://github.com/jmespath/jmespath.test
final class ComplianceTests: XCTestCase {
    struct ComplianceTest: Decodable {
        struct Case: Decodable {
            let expression: String
            let error: String?
            let bench: String?
            let result: String?
            let comment: String?

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.expression = try container.decode(String.self, forKey: .expression)
                self.error = try container.decodeIfPresent(String.self, forKey: .error)
                self.bench = try container.decodeIfPresent(String.self, forKey: .bench)
                self.comment = try container.decodeIfPresent(String.self, forKey: .comment)
                guard let anyDecodable = try container.decodeIfPresent(AnyDecodable.self, forKey: .result) else {
                    self.result = nil
                    return
                }
                let jsonData = try JSONSerialization.data(
                    withJSONObject: anyDecodable.value,
                    options: [.fragmentsAllowed, .sortedKeys]
                )
                self.result = String(decoding: jsonData, as: Unicode.UTF8.self)
            }

            private enum CodingKeys: String, CodingKey {
                case expression
                case error
                case bench
                case result
                case comment
            }
        }

        let given: String
        let cases: [Case]
        let comment: String?

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.cases = try container.decode([Case].self, forKey: .cases)
            self.comment = try container.decodeIfPresent(String.self, forKey: .comment)
            let anyDecodable = try container.decode(AnyDecodable.self, forKey: .given)
            let jsonData = try JSONSerialization.data(
                withJSONObject: anyDecodable.value,
                options: [.fragmentsAllowed, .sortedKeys]
            )
            self.given = String(decoding: jsonData, as: Unicode.UTF8.self)
        }

        private enum CodingKeys: String, CodingKey {
            case given
            case cases
            case comment
        }
        @available(iOS 11.0, tvOS 11.0, watchOS 5.0, *)
        func run() throws {
            for c in self.cases {
                if c.bench != nil {
                    self.testBenchmark(c)
                } else if let error = c.error {
                    self.testError(c, error: error)
                } else {
                    self.testResult(c)
                }
            }
        }

        func testBenchmark(_ c: Case) {
            do {
                let expression = try JMESExpression.compile(c.expression)
                _ = try expression.search(json: self.given)
            } catch {
                XCTFail("\(error)")
            }
        }

        func testError(_ c: Case, error: String) {
            do {
                let expression = try JMESExpression.compile(c.expression)
                _ = try expression.search(json: self.given)
            } catch {
                return
            }
            if let comment = c.comment {
                print("Test: \(comment)")
            }
            print("Expression: \(c.expression)")
            XCTFail("Should throw an error")
        }

        func convertNulls(_ value: Any) -> Any {
            switch value {
            case is JMESNull:
                NSNull()
            case let array as [Any]:
                array.map { convertNulls($0) }
            case let object as [String: Any]:
                object.mapValues { convertNulls($0) }
            default:
                value
            }
        }

        @available(iOS 11.0, tvOS 11.0, watchOS 5.0, *)
        func testResult(_ c: Case) {
            let expectedResult = c.result
            do {
                let expression = try JMESExpression.compile(c.expression)

                if let value = try expression.search(json: self.given) {
                    let valueData = try JSONSerialization.data(
                        withJSONObject: convertNulls(value),
                        options: [.fragmentsAllowed, .sortedKeys]
                    )
                    let valueJson = String(decoding: valueData, as: Unicode.UTF8.self)
                    XCTAssertEqual(expectedResult, valueJson, c.comment ?? c.expression)
                } else {
                    XCTAssertNil(expectedResult)
                }
            } catch {
                XCTFail("\(error)")
            }
        }

        @available(iOS 11.0, tvOS 11.0, watchOS 5.0, *)
        func output(_ c: Case, expected: String?, result: String?) {
            if expected != result {
                if let comment = c.comment {
                    print("Comment: \(comment)")
                }
                print("Expression: \(c.expression)")
                print("Given: \(given)")
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
