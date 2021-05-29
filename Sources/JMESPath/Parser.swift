
class Parser {
    let tokens: [Token]
    var index: Int

    init(tokens: [Token]) {
        self.tokens = tokens
        self.index = 0
    }

    func parse() throws -> Ast {
        try self.expression(rbp: 0)
    }

    func expression(rbp: Int) throws -> Ast {
        var left = try nud()
        while rbp < self.peek(0).lbp {
            left = try self.led(left: left)
        }
        return left
    }

    func nud() throws -> Ast {
        let token = self.advance()
        switch token {
        case .at:
            return .identity

        case .identifier(let value):
            return .field(name: value)

        case .quotedIdentifier(let value):
            if self.peek() == .leftParenthesis {
                throw JMESError.quotedIdentiferNotFunction
            }
            return .field(name: value)

        case .star:
            return try self.parseWildcardValues(lhs: .identity)

        case .literal(let variable):
            return .literal(value: variable)

        case .leftBracket:
            switch (self.peek(0), self.peek(1)) {
            case (.number, _), (.colon, _):
                return try self.parseIndex()
            case (.star, .rightBracket):
                self.advance()
                return try self.parseWildcardIndex(lhs: .identity)
            default:
                return try self.parseMultiList()
            }

        case .flatten:
            return try self.parseFlatten(lhs: .identity)

        case .leftBrace:
            var pairs: [String: Ast] = [:]
            exitLoop: while true {
                let pair = try parseKeyValuePair()
                pairs[pair.key] = pair.value
                switch self.advance() {
                case .rightBrace:
                    break exitLoop
                case .comma:
                    break
                default:
                    throw JMESError.invalidToken
                }
            }
            return .multiHash(elements: pairs)

        case .ampersand:
            let rhs = try expression(rbp: Token.ampersand.lbp)
            return .expRef(ast: rhs)

        case .not:
            let node = try expression(rbp: Token.not.lbp)
            return .not(node: node)

        case .filter:
            return try self.parseFilter(lhs: .identity)

        case .leftParenthesis:
            let result = try expression(rbp: 0)
            switch self.advance() {
            case .rightParenthesis:
                return result
            default:
                throw JMESError.invalidToken
            }

        default:
            throw JMESError.invalidToken
        }
    }

    func led(left: Ast) throws -> Ast {
        switch self.advance() {
        case .dot:
            if self.peek() == .star {
                self.advance()
                return try self.parseWildcardValues(lhs: left)
            } else {
                let rhs = try parseDot(lbp: Token.dot.lbp)
                return .subExpr(lhs: left, rhs: rhs)
            }

        case .leftBracket:
            var isNumber: Bool
            switch self.peek() {
            case .number, .colon:
                isNumber = true
            case .star:
                isNumber = false
            default:
                throw JMESError.invalidToken
            }
            if isNumber {
                return .subExpr(lhs: left, rhs: try self.parseIndex())
            } else {
                self.advance()
                return try self.parseWildcardIndex(lhs: left)
            }

        case .or:
            let rhs = try expression(rbp: Token.or.lbp)
            return .or(lhs: left, rhs: rhs)

        case .and:
            let rhs = try expression(rbp: Token.and.lbp)
            return .or(lhs: left, rhs: rhs)

        case .pipe:
            let rhs = try expression(rbp: Token.pipe.lbp)
            return .subExpr(lhs: left, rhs: rhs)

        case .leftParenthesis:
            switch left {
            case .field(let name):
                return .function(name: name, args: try self.parseList(closing: .rightParenthesis))
            default:
                throw JMESError.invalidToken
            }

        case .flatten:
            return try self.parseFlatten(lhs: left)

        case .filter:
            return try self.parseFilter(lhs: left)

        case .equals:
            return try self.parseComparator(Comparator.equal, lhs: left)
        case .notEqual:
            return try self.parseComparator(Comparator.notEqual, lhs: left)
        case .lessThan:
            return try self.parseComparator(Comparator.lessThan, lhs: left)
        case .lessThanOrEqual:
            return try self.parseComparator(Comparator.lessThanOrEqual, lhs: left)
        case .greaterThan:
            return try self.parseComparator(Comparator.greaterThan, lhs: left)
        case .greaterThanOrEqual:
            return try self.parseComparator(Comparator.greaterThanOrEqual, lhs: left)

        default:
            throw JMESError.invalidToken
        }
    }

    func parseKeyValuePair() throws -> (key: String, value: Ast) {
        switch self.advance() {
        case .identifier(let value), .quotedIdentifier(let value):
            if self.peek() == .colon {
                self.advance()
                return (key: value, value: try self.expression(rbp: 0))
            } else {
                throw JMESError.invalidToken
            }
        default:
            throw JMESError.invalidToken
        }
    }

    func parseFilter(lhs: Ast) throws -> Ast {
        let conditionLHS = try self.expression(rbp: 0)
        switch self.advance() {
        case .rightBracket:
            let conditionRHS = try projectionRHS(lbp: Token.filter.lbp)
            return .projection(lhs: lhs, rhs: .condition(predicate: conditionLHS, then: conditionRHS))
        default:
            throw JMESError.invalidToken
        }
    }

    func parseFlatten(lhs: Ast) throws -> Ast {
        let rhs = try projectionRHS(lbp: Token.flatten.lbp)
        return .projection(
            lhs: .flatten(node: lhs),
            rhs: rhs
        )
    }

    func parseComparator(_ comparator: Comparator, lhs: Ast) throws -> Ast {
        let rhs = try expression(rbp: Token.equals.lbp)
        return .comparison(comparator: comparator, lhs: lhs, rhs: rhs)
    }

    func parseDot(lbp: Int) throws -> Ast {
        let isMultiList: Bool
        switch self.peek() {
        case .leftBracket:
            isMultiList = true
        case .identifier, .quotedIdentifier, .star, .leftBrace, .ampersand:
            isMultiList = false
        default:
            throw JMESError.invalidToken
        }
        if isMultiList {
            self.advance()
            return try self.parseMultiList()
        } else {
            return try self.expression(rbp: lbp)
        }
    }

    func projectionRHS(lbp: Int) throws -> Ast {
        let projectionStop = 10
        let isDot: Bool
        let token = self.peek()
        switch (token, token.lbp) {
        case (.dot, _):
            isDot = true
        case (.leftBracket, _):
            isDot = false
        case (_, 0..<projectionStop):
            return .identity
        default:
            throw JMESError.invalidToken
        }
        if isDot {
            self.advance()
            return try self.parseDot(lbp: lbp)
        } else {
            return try self.expression(rbp: lbp)
        }
    }

    func parseWildcardIndex(lhs: Ast) throws -> Ast {
        switch self.advance() {
        case .rightBracket:
            let rhs = try projectionRHS(lbp: Token.star.lbp)
            return .projection(lhs: lhs, rhs: rhs)
        default:
            throw JMESError.invalidToken
        }
    }

    func parseWildcardValues(lhs: Ast) throws -> Ast {
        let rhs = try projectionRHS(lbp: Token.star.lbp)
        return .projection(lhs: .objectValues(node: lhs), rhs: rhs)
    }

    func parseMultiList() throws -> Ast {
        return try .multiList(elements: self.parseList(closing: .rightBracket))
    }

    func parseList(closing: Token) throws -> [Ast] {
        var nodes: [Ast] = []
        while self.peek() != closing {
            nodes.append(try self.expression(rbp: 0))
            if self.peek() == .comma {
                self.advance()
                if self.peek() == closing {
                    throw JMESError.invalidToken
                }
            }
        }
        self.advance()
        return nodes
    }

    func parseIndex() throws -> Ast {
        var parts: [Int?] = [nil, nil, nil]
        var index = 0
        exitLoop: while true {
            switch self.advance() {
            case .number(let value):
                parts[index] = value
                switch self.peek() {
                case .colon, .rightBracket:
                    break
                default:
                    throw JMESError.invalidToken
                }

            case .rightBracket:
                break exitLoop

            case .colon:
                index += 1
                if index > 2 {
                    throw JMESError.invalidToken
                }
                switch self.peek() {
                case .number, .colon, .rightBracket:
                    break
                default:
                    throw JMESError.invalidToken
                }

            default:
                throw JMESError.invalidToken
            }
        }

        if index == 0 {
            if let part = parts[0] {
                return .index(index: part)
            } else {
                throw JMESError.invalidToken
            }
        } else {
            return .projection(
                lhs: .slice(
                    start: parts[0],
                    stop: parts[1],
                    step: parts[2] ?? 1
                ),
                rhs: try self.projectionRHS(lbp: Token.star.lbp)
            )
        }
    }

    @discardableResult private func advance() -> Token {
        let token = self.tokens[self.index]
        self.index += 1
        return token
    }

    private func peek(_ offset: Int = 0) -> Token {
        guard offset + self.index < self.tokens.count else { return .eof }
        return self.tokens[offset + self.index]
    }
}
