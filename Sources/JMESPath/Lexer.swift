import Foundation

public class Lexer {
    var index: String.Index
    let text: String

    public init(text: String) {
        self.text = text
        self.index = text.startIndex
    }

    
    func tokenize() throws -> [Token] {
        var tokens: [Token] = []

        while !reachedEnd() {
            let c = current()

            switch c {
            case "a"..."z", "A"..."Z", "_":
                tokens.append(.identifier(readIdentifier()))
                continue
            case "\"":
                try tokens.append(.quotedIdentifier(readQuotedIdentifier()))
            case "'":
                try tokens.append(.literal(readRawString()))
            case "0"..."9":
                try tokens.append(.number(readNumber()))
                continue
            case "-":
                try tokens.append(.number(readNegativeNumber()))
                continue
            case "`":
                try tokens.append(.literal(readLiteral()))
            case ".":
                tokens.append(.dot)
            case "*":
                tokens.append(.star)
            case "|":
                tokens.append(alternative(expected: "|", match: .or, else: .pipe))
            case "@":
                tokens.append(.at)
            case "[":
                tokens.append(readLeftBracket())
            case "]":
                tokens.append(.rightBracket)
            case ",":
                tokens.append(.comma)
            case ":":
                tokens.append(.colon)
            case "{":
                tokens.append(.leftBrace)
            case "}":
                tokens.append(.rightBrace)
            case "&":
                tokens.append(alternative(expected: "&", match: .and, else: .ampersand))
            case "(":
                tokens.append(.leftParenthesis)
            case ")":
                tokens.append(.rightParenthesis)
            case "=":
                tokens.append(.equals)
                try expect("=")
            case ">":
                tokens.append(alternative(expected: "=", match: .greaterThanOrEqual, else: .greaterThan))
            case "<":
                // check next char
                tokens.append(alternative(expected: "=", match: .lessThanOrEqual, else: .lessThan))
            case "!":
                // check next char
                tokens.append(alternative(expected: "=", match: .notEqual, else: .not))
            case " ", "\n", "\t", "\r":
                break
            default:
                throw JMESError.invalidCharacter
            }

            next()
        }
        tokens.append(.eof)
        return tokens
    }

    private func readIdentifier() -> String {
        let identifierStart = self.index
        exitLoop: while !reachedEnd() {
            switch current() {
            case "a"..."z", "A"..."Z", "_", "0"..."9":
                break
            default:
                break exitLoop
            }
            next()
        }
        return String(self.text[identifierStart..<self.index])
    }

    private func readLeftBracket() -> Token {
        switch peek() {
        case "]":
            next()
            return .flatten
        case "?":
            next()
            return .filter
        default:
            return .leftBracket
        }
    }

    private func readNumber() throws -> Int {
        let identifierStart = self.index
        exitLoop: while !reachedEnd() {
            switch current() {
            case "0"..."9":
                break
            default:
                break exitLoop
            }
            next()
        }
        guard let int = Int(self.text[identifierStart..<self.index]) else {
            throw JMESError.invalidInteger
        }
        return int
    }

    private func readNegativeNumber() throws -> Int {
        let identifierStart = self.index
        next()
        exitLoop: while !reachedEnd() {
            switch current() {
            case "0"..."9":
                break
            default:
                break exitLoop
            }
            next()
        }
        guard let int = Int(self.text[identifierStart..<self.index]) else {
            throw JMESError.invalidInteger
        }
        return int
    }

    private func readQuotedIdentifier() throws -> String {
        let string = try readInside()
        let expanded = try JSONSerialization.jsonObject(with: Data("\"\(string)\"".utf8), options: [.allowFragments, .fragmentsAllowed])
        return expanded as! String
    }

    private func readRawString() throws -> Variable {
        return try .string(readInside())
    }

    private func readLiteral() throws -> Variable {
        let string = try readInside()
        do {
            let expanded = try JSONSerialization.jsonObject(with: Data(string.utf8), options: [.allowFragments, .fragmentsAllowed])
            return try Variable(from: expanded)
        } catch {
            throw JMESError.invalidLiteral
        }
    }

    private func readInside() throws -> String {
        let wrapper = current()
        next()
        let start = self.index
        exitLoop: while !reachedEnd() {
            let c = current()
            switch c {
            case wrapper:
                let buffer = self.text[start..<self.index]
                return String(buffer)
            case "\\":
                next()
                guard !reachedEnd() else { throw JMESError.unclosedDelimiter }
            default:
                break
            }
            next()
        }
        throw JMESError.unclosedDelimiter
    }

    private func expect(_ expected: Character) throws {
        next()
        guard self.index != self.text.endIndex, self.text[self.index] == expected else { throw JMESError.unexpectedCharacter }
    }

    private func alternative(expected: Character, match: Token, else: Token) -> Token {
        if peek() == expected {
            next()
            return match
        }
        return `else`
    }

    private func peek() -> Character? {
        let nextIndex = self.text.index(after: self.index)
        guard nextIndex != self.text.endIndex else { return nil }
        return self.text[nextIndex]
    }

    private func current() -> Character {
        self.text[self.index]
    }

    private func next() {
        self.index = self.text.index(after: self.index)
    }

    private func reachedEnd() -> Bool {
        return self.index == text.endIndex
    }
}
