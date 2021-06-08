/// Parser object.
///
/// Parses array of tokens to create AST
internal class Parser {
    let tokens: [Token]
    var index: Int

    init(tokens: [Token]) {
        self.tokens = tokens
        self.index = 0
    }

    func parse() throws -> Ast {
        let result = try self.expression(rbp: 0)
        guard case .eof = self.peek() else {
            throw JMESPathError.compileTime("Did you not parse the complete expression")
        }
        return result
    }

    /// Main parse function of the Pratt parser. Continue to parse while rbp is less then lbp
    func expression(rbp: Int) throws -> Ast {
        var left = try nud()
        while rbp < self.peek(0).lbp {
            left = try self.led(left: left)
        }
        return left
    }

    /// null denotation, head handler function
    func nud() throws -> Ast {
        let token = self.advance()
        switch token {
        case .at:
            return .identity

        case .identifier(let value):
            return .field(name: value)

        case .quotedIdentifier(let value):
            if self.peek() == .leftParenthesis {
                throw JMESPathError.compileTime("Quoted strings cannot be a function name")
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
                let token = self.advance()
                switch token {
                case .rightBrace:
                    break exitLoop
                case .comma:
                    break
                default:
                    throw JMESPathError.compileTime("Expected '}' or ',', not a '\(token)'")
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
            let token = self.advance()
            switch token {
            case .rightParenthesis:
                return result
            default:
                throw JMESPathError.compileTime("Expected ')' to close '(', not a '\(token)'")
            }

        default:
            throw JMESPathError.compileTime("Unexpected token '\(token)'")
        }
    }

    /// left denotation, tail handler function
    func led(left: Ast) throws -> Ast {
        let token = self.advance()
        switch token {
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
            let token = self.peek()
            switch token {
            case .number, .colon:
                isNumber = true
            case .star:
                isNumber = false
            default:
                throw JMESPathError.compileTime("Expected number, ':' or '*', not a '\(token)'")
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
            return .and(lhs: left, rhs: rhs)

        case .pipe:
            let rhs = try expression(rbp: Token.pipe.lbp)
            return .subExpr(lhs: left, rhs: rhs)

        case .leftParenthesis:
            switch left {
            case .field(let name):
                return .function(name: name, args: try self.parseList(closing: .rightParenthesis))
            default:
                throw JMESPathError.compileTime("Invalid function name '\(left)'")
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
            throw JMESPathError.compileTime("Unexpected token '\(token)'")
        }
    }

    /// key : value
    func parseKeyValuePair() throws -> (key: String, value: Ast) {
        let token = self.advance()
        switch token {
        case .identifier(let value), .quotedIdentifier(let value):
            let token2 = self.peek()
            if token2 == .colon {
                self.advance()
                return (key: value, value: try self.expression(rbp: 0))
            } else {
                throw JMESPathError.compileTime("Expected a ':' to follow key, not a '\(token2)'")
            }
        default:
            throw JMESPathError.compileTime("Expected field to start key value pair, not a '\(token)'")
        }
    }

    /// [?...]
    func parseFilter(lhs: Ast) throws -> Ast {
        let conditionLHS = try self.expression(rbp: 0)
        let token = self.advance()
        switch token {
        case .rightBracket:
            let conditionRHS = try projectionRHS(lbp: Token.filter.lbp)
            return .projection(lhs: lhs, rhs: .condition(predicate: conditionLHS, then: conditionRHS))
        default:
            throw JMESPathError.compileTime("Expected a ']' to end filter, not '\(token)'")
        }
    }

    /// []
    func parseFlatten(lhs: Ast) throws -> Ast {
        let rhs = try projectionRHS(lbp: Token.flatten.lbp)
        return .projection(
            lhs: .flatten(node: lhs),
            rhs: rhs
        )
    }

    /// ==, !=, <, <=, >, >=
    func parseComparator(_ comparator: Comparator, lhs: Ast) throws -> Ast {
        let rhs = try expression(rbp: Token.equals.lbp)
        return .comparison(comparator: comparator, lhs: lhs, rhs: rhs)
    }

    func parseDot(lbp: Int) throws -> Ast {
        let isMultiList: Bool
        let token = self.peek()
        switch token {
        case .leftBracket:
            isMultiList = true
        case .identifier, .quotedIdentifier, .star, .leftBrace, .ampersand:
            isMultiList = false
        default:
            throw JMESPathError.compileTime("Expected identifier, '*', '{', '[', '&', or '[?', not '\(token)'")
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
        case (.leftBracket, _), (.filter, _):
            isDot = false
        case (_, 0..<projectionStop):
            return .identity
        default:
            throw JMESPathError.compileTime("Expected '.', '[', or '[?', not '\(token)'")
        }
        if isDot {
            self.advance()
            return try self.parseDot(lbp: lbp)
        } else {
            return try self.expression(rbp: lbp)
        }
    }

    func parseWildcardIndex(lhs: Ast) throws -> Ast {
        let token = self.advance()
        switch token {
        case .rightBracket:
            let rhs = try projectionRHS(lbp: Token.star.lbp)
            return .projection(lhs: lhs, rhs: rhs)
        default:
            throw JMESPathError.compileTime("Expected ']' after wildcard index, not '\(token)'")
        }
    }

    /// [*]
    func parseWildcardValues(lhs: Ast) throws -> Ast {
        let rhs = try projectionRHS(lbp: Token.star.lbp)
        return .projection(lhs: .objectValues(node: lhs), rhs: rhs)
    }

    /// [1,2,3,4]
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
                    throw JMESPathError.compileTime("Invalid token '\(self.peek())' after ','")
                }
            }
        }
        self.advance()
        return nodes
    }

    /// Parses indices [0] and slices [1:5]
    func parseIndex() throws -> Ast {
        var parts: [Int?] = [nil, nil, nil]
        var index = 0
        exitLoop: while true {
            let token = self.advance()
            switch token {
            case .number(let value):
                parts[index] = value
                switch self.peek() {
                case .colon, .rightBracket:
                    break
                default:
                    throw JMESPathError.compileTime("Expected ':' or ']' after index, not '\(self.peek())'")
                }

            case .rightBracket:
                break exitLoop

            case .colon:
                index += 1
                if index > 2 {
                    throw JMESPathError.compileTime("Slice contains too many ':'s")
                }
                switch self.peek() {
                case .number, .colon, .rightBracket:
                    break
                default:
                    throw JMESPathError.compileTime("Expected number, ':' or ']', not '\(self.peek())'")
                }

            default:
                throw JMESPathError.compileTime("Expected number, ':' or ']', not '\(token)'")
            }
        }

        if index == 0 {
            if let part = parts[0] {
                return .index(index: part)
            } else {
                throw JMESPathError.compileTime("Expected a number")
            }
        } else {
            let step = parts[2] ?? 1
            if step == 0 {
                throw JMESPathError.compileTime("Slice step cannot be 0")
            }
            return .projection(
                lhs: .slice(
                    start: parts[0],
                    stop: parts[1],
                    step: step
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
