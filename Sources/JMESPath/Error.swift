public struct JMESError: Error, Equatable {
    // Lexer errors
    public static var invalidCharacter: Self { .init(value: .invalidCharacter) }
    public static var unexpectedCharacter: Self { .init(value: .unexpectedCharacter) }
    public static var invalidInteger: Self { .init(value: .invalidInteger) }
    public static var invalidLiteral: Self { .init(value: .invalidLiteral) }
    public static var invalidComparator: Self { .init(value: .invalidComparator) }
    public static var unclosedDelimiter: Self { .init(value: .unclosedDelimiter) }
    public static var failedToCreateLiteral: Self { .init(value: .failedToCreateLiteral) }
    // Parser errors
    public static var invalidToken: Self { .init(value: .invalidToken) }
    public static var quotedIdentiferNotFunction: Self { .init(value: .quotedIdentiferNotFunction) }

    private enum Internal {
        // lever errors
        case invalidCharacter
        case unexpectedCharacter
        case invalidInteger
        case invalidLiteral
        case invalidComparator
        case unclosedDelimiter
        case failedToCreateLiteral
        // parser errors
        case invalidToken
        case quotedIdentiferNotFunction
    }
    private let value: Internal
}
