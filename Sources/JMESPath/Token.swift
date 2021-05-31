enum Token: Equatable {
    case identifier(String)
    case quotedIdentifier(String)
    case number(Int)
    case literal(JMESVariable)
    case dot
    case star
    case flatten
    case and
    case or
    case pipe
    case filter
    case leftBracket
    case rightBracket
    case comma
    case colon
    case not
    case notEqual
    case equals
    case greaterThan
    case greaterThanOrEqual
    case lessThan
    case lessThanOrEqual
    case at
    case ampersand
    case leftParenthesis
    case rightParenthesis
    case leftBrace
    case rightBrace
    case eof
}

extension Token {
    var lbp: Int {
        switch self {
        case .pipe: return 1
        case .or: return 2
        case .and: return 3
        case .equals: return 5
        case .greaterThan: return 5
        case .lessThan: return 5
        case .greaterThanOrEqual: return 5
        case .lessThanOrEqual: return 5
        case .notEqual: return 5
        case .flatten: return 9
        case .star: return 20
        case .filter: return 21
        case .dot: return 40
        case .not: return 45
        case .leftBrace: return 50
        case .leftBracket: return 55
        case .leftParenthesis: return 60
        default: return 0
        }
    }
}
