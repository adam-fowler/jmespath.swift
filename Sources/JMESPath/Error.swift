/// JMESPath error type.
///
/// Provides two errors, compile time and run time errors
public struct JMESPathError: Error, Equatable {
    /// Error that occurred while compiling JMESPath
    public static func compileTime(_ message: String) -> Self { .init(value: .compileTime(message)) }
    /// Error that occurred while running a search
    public static func runtime(_ message: String) -> Self { .init(value: .runtime(message)) }

    private enum Internal: Equatable {
        case compileTime(String)
        case runtime(String)
    }

    private let value: Internal
}
