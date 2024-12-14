import Foundation

/// JMESExpression extensions for Data
extension JMESExpression {
    /// Search JSON
    ///
    /// - Parameters:
    ///   - any: JSON to search
    ///   - as: Swift type to return
    ///   - runtime: JMES runtime (includes functions)
    /// - Throws: JMESPathError
    /// - Returns: Search result
    public func search<Value>(json: Data, as: Value.Type = Value.self, runtime: JMESRuntime = .init()) throws -> Value {
        let searchResult = try self.search(json: json, runtime: runtime)
        guard let value = searchResult as? Value else {
            throw JMESPathError.runtime("Expected \(Value.self)) but got a \(type(of: searchResult))")
        }
        return value
    }

    /// Search JSON
    ///
    /// - Parameters:
    ///   - any: JSON to search
    ///   - runtime: JMES runtime (includes functions)
    /// - Throws: JMESPathError
    /// - Returns: Search result
    public func search(json: Data, runtime: JMESRuntime = .init()) throws -> Any? {
        let value = try JMESJSON.parse(json: json)
        return try runtime.interpret(JMESVariable(from: value), ast: self.ast).collapse()
    }
}

/// Parse json in the form of Data
extension JMESJSON {
    static func parse(json: Data) throws -> Any {
        try json.withBufferView { view in
            var scanner = JSONScanner(bytes: view, options: .init())
            let map = try scanner.scan()
            guard let value = map.loadValue(at: 0) else { throw JMESPathError.runtime("Empty JSON file") }
            return try JMESJSONVariable(value: value).getValue(map)
        }
    }
}
