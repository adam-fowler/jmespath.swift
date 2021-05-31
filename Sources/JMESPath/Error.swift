public struct JMESPathError: Error, Equatable {
    public static func syntaxError(_ message: String) -> Self { .init(value: .syntaxError(message))}
    public static func invalidArguments(_ message: String) -> Self { .init(value: .invalidArguments(message))}
    public static func invalidType(_ message: String) -> Self { .init(value: .invalidType(message))}
    public static func invalidValue(_ message: String) -> Self { .init(value: .invalidValue(message))}
    public static func unknownFunction(_ message: String) -> Self { .init(value: .unknownFunction(message))}
    public static func runtime(_ message: String) -> Self { .init(value: .runtime(message))}

    private enum Internal: Equatable {
        case syntaxError(String)
        case invalidArguments(String)
        case invalidType(String)
        case invalidValue(String)
        case unknownFunction(String)
        case runtime(String)
    }

    private let value: Internal
}
