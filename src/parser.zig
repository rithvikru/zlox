const std = @import("std");
const Token = @import("scanner.zig").Token;
const TokenType = @import("scanner.zig").TokenType;

const Parser = @This();

tokens: std.ArrayList(Token),
current: usize,

pub fn init(allocator: *std.mem.Allocator, tokens: std.ArrayList(Token)) Parser {
    return Parser{
        .tokens = tokens,
        .current = 0,
    };
}

fn expression(self: *Parser) *Expression {
    return self.equality();
}

fn equality(self: *Parser) *Expression {
    var expr = self.comparison();
    while (self.match(.BANG_EQUAL, .EQUAL_EQUAl)) {
        const operator = self.previous();
        const right = self.comparison();
        expr = Expression{
            .binary = Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            },
        };
    }
    return expr;
}

fn term(self: *Parser) *Expression {
    var expr = self.factor();
    while (self.match(.MINUS, .PLUS)) {
        const operator = self.previous();
        const right = self.factor();
        expr = Expression{
            .binary = Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            },
        };
    }
    return expr;
}

fn factor(self: *Parser) *Expression {
    var expr = self.unary();
    while (self.match(.SLASH, .STAR)) {
        const operator = self.previous();
        const right = self.unary();
        expr = Expression{
            .binary = Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            },
        };
    }
    return expr;
}

fn unary(self: *Parser) *Expression {
    if (self.match(.BANG, .MINUS)) {
        const operator = self.previous();
        const right = self.unary();
        return Expression{
            .unary = Unary{
                .operator = operator,
                .right = right,
            },
        };
    }
    return self.primary();
}

fn comparison(self: *Parser) *Expression {
    var expr = self.term();
    while (self.match(GREATER, GREATER_EQUAL, LESS, LESS_EQUAL)) {
        const operator = self.previous();
        const right = self.term();
        expr = Expression{
            .binary = Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            },
        };
    }
    return expr;
}

fn primary(self: *Parser) *Expression {
    if (self.match(.FALSE)) {
        return Expression{
            .literal = Literal{
                .bool = false,
            }
        }
    }
    if (self.match(.TRUE)) {
        return Expression{
            .literal = Literal{
                .bool = true,
            }
        }
    }
    if (self.match(.NIL)) {
        return Expression{
            .literal = Literal{
                .nil = {},
            }
        }
    }

    if (self.match(.NUMBER)) {
        return Expression{
            .literal = Literal{
                .number = std.fmt.parseFloat(f64, self.previous().lexeme),
            }
        }
    }

    if (self.match(.LEFT_PAREN)) {
        const expr = self.expression();
        try self.consume(.RIGHT_PAREN, "Expect ')' after expression.");
        return Expression{
            .grouping = Grouping{
                .expression = expr,
            },
        };
    }
}

fn consume(self: *Parser, ttype: TokenType, message: []const u8) Token {
    if (self.check(ttype)) {
        return self.advance();
    }
    return self.makeError(message);
}

fn synchronize(self: *Parser) void {
    self.advance();
    while (!self.isAtEnd()) {
        if (self.previous().ttype == .SEMICOLON) {
            return;
        }
        switch (self.peek().ttype) {
            .CLASS, .FUN, .VAR, .FOR, .IF, .WHILE, .PRINT, .RETURN => return,
            else => {},
        }
        self.advance();
    }
}

fn match(self: *Parser, ttypes: anytype) bool {
    for (ttypes) |ttype| {
        if (self.check(ttype)) {
            self.advance();
            return true;
        }
    }
    return false;
}

fn check(self: *Parser, ttype: TokenType) bool {
    if (self.isAtEnd()) {
        return false;
    }
    return self.peek().ttype == ttype;
}

fn advance(self: *Parser) Token {
    if (!self.isAtEnd()) {
        self.current += 1;
    }
    return self.previous();
}

fn isAtEnd(self: *Parser) bool {
    return self.peek().ttype == .EOF;
}

fn peek(self: *Parser) Token {
    return self.tokens[self.current];
}

fn previous(self: *Parser) Token {
    return self.tokens[self.current - 1];
}
