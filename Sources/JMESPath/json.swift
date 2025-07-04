#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Namespace to wrap JSON parsing code
enum JMESJSON {
    ///  Parse JSON into object
    /// - Parameter json: json string
    /// - Returns: object
    static func parse(json: String) throws -> Any {
        try json.withBufferView { view in
            var scanner = JSONScanner(bytes: view, options: .init())
            let map = try scanner.scan()
            guard let value = map.loadValue(at: 0) else { throw JMESPathError.runtime("Empty JSON file") }
            return try JMESJSONVariable(value: value).getValue(map)
        }
    }

    ///  Parse JSON into object
    /// - Parameter json: json string
    /// - Returns: object
    static func parse(json: some ContiguousBytes) throws -> Any {
        try json.withBufferView { view in
            var scanner = JSONScanner(bytes: view, options: .init())
            let map = try scanner.scan()
            guard let value = map.loadValue(at: 0) else { throw JMESPathError.runtime("Empty JSON file") }
            return try JMESJSONVariable(value: value).getValue(map)
        }
    }

}

struct JMESJSONVariable {
    let value: JSONMap.Value
    init(value: JSONMap.Value) {
        self.value = value
    }

    init?(json: String) throws {
        guard
            let variable = try json.withBufferView({ view -> JMESJSONVariable? in
                var scanner = JSONScanner(bytes: view, options: .init())
                let map = try scanner.scan()
                guard let value = map.loadValue(at: 0) else { return nil }
                return JMESJSONVariable(value: value)
            })
        else { return nil }
        self = variable
    }
}

extension JMESJSONVariable {
    func getValue(_ map: JSONMap) throws -> Any {
        switch self.value {
        case .string(let region, let isSimple):
            return try map.withBuffer(for: region) { stringBuffer, fullSource in
                if isSimple {
                    guard let result = String._tryFromUTF8(stringBuffer) else {
                        throw JSONError.cannotConvertInputStringDataToUTF8(
                            location: .sourceLocation(at: stringBuffer.startIndex, fullSource: fullSource)
                        )
                    }
                    return result
                }
                return try JSONScanner.stringValue(from: stringBuffer, fullSource: fullSource)
            }

        case .bool(let value):
            return value

        case .null:
            return JMESNull()

        case .number(let region, let hasExponent):
            return try map.withBuffer(for: region) { numberBuffer, fullSource in
                if hasExponent {
                    let digitsStartPtr = try JSONScanner.prevalidateJSONNumber(from: numberBuffer, hasExponent: hasExponent, fullSource: fullSource)

                    if let floatingPoint = Double(prevalidatedBuffer: numberBuffer) {
                        // Check for overflow (which results in an infinite result), or rounding to zero.
                        // While strtod does set ERANGE in the either case, we don't rely on it because setting errno to 0 first and then check the result is surprisingly expensive. For values "rounded" to infinity, we reject those out of hand. For values "rounded" down to zero, we perform check for any non-zero digits in the input, which turns out to be much faster.
                        if floatingPoint.isFinite {
                            // Should also check for underflow here
                            return floatingPoint
                        } else {
                            throw JSONError.numberIsNotRepresentableInSwift(parsed: String(decoding: numberBuffer, as: UTF8.self))
                        }
                    }
                    throw JSONScanner.validateNumber(from: numberBuffer.suffix(from: digitsStartPtr), fullSource: fullSource)

                } else {
                    let digitBeginning = try JSONScanner.prevalidateJSONNumber(from: numberBuffer, hasExponent: hasExponent, fullSource: fullSource)
                    // This is the fast pass. Number directly convertible to Integer.
                    if let integer = Int(prevalidatedBuffer: numberBuffer) {
                        return integer
                    }
                    if let double = Double(prevalidatedBuffer: numberBuffer) {
                        return double
                    }
                    throw JSONScanner.validateNumber(from: numberBuffer.suffix(from: digitBeginning), fullSource: fullSource)
                }
            }

        case .array(let region):
            var entries = [JMESJSONVariable]()
            var iterator = map.makeArrayIterator(from: region.startOffset)
            while let value = iterator.next() {
                entries.append(.init(value: value))
            }
            return try entries.map { try $0.getValue(map) }

        case .object(let region):
            var entries = [String: JMESJSONVariable]()
            var iterator = map.makeObjectIterator(from: region.startOffset)
            while let value = iterator.next() {
                guard case .string(let region, let isSimple) = value.key else {
                    throw JMESPathError.runtime("Non string dictionary keys are not supported.")
                }
                let key = try map.withBuffer(for: region) { stringBuffer, fullSource in
                    if isSimple {
                        guard let result = String._tryFromUTF8(stringBuffer) else {
                            throw JSONError.cannotConvertInputStringDataToUTF8(
                                location: .sourceLocation(at: stringBuffer.startIndex, fullSource: fullSource)
                            )
                        }
                        return result
                    }
                    return try JSONScanner.stringValue(from: stringBuffer, fullSource: fullSource)
                }
                entries[key] = .init(value: value.value)
            }
            return try entries.mapValues { try $0.getValue(map) }
        }
    }
}
