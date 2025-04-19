const std = @import("std");
const Token = @import("scanner.zig").Token;
const TokenType = @import("scanner.zig").TokenType;
const Allocator = std.mem.Allocator;

const ast = @import("ast.zig");
const Expression = ast.Expression;
const Binary = ast.Binary;
const Unary = ast.Unary;
const Literal = ast.Literal;
const Grouping = ast.Grouping;

const Parser = @This();

const ParseError = error{
    ExpectedExpression,
    ExpectedRightParen,
    OutOfMemory,
};

allocator: Allocator,
tokens: std.ArrayList(Token),
current: usize,

pub fn init(allocator: Allocator, tokens: std.ArrayList(Token)) Parser {
    return Parser{
        .allocator = allocator,
        .tokens = tokens,
        .current = 0,
    };
}

pub fn parse(self: *Parser) ParseError!*Expression {
    return self.expression();
}

fn expression(self: *Parser) ParseError!*Expression {
    return try self.equality();
}

fn equality(self: *Parser) ParseError!*Expression {
    var expr = try self.comparison();
    while (self.match(&[_]TokenType{ .BANG_EQUAL, .EQUAL_EQUAL })) {
        const operator = self.previous();
        const right = try self.comparison();
        const binary_expr = try self.allocator.create(Expression);
        binary_expr.* = Expression{
            .binary = Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            },
        };
        expr = binary_expr;
    }
    return expr;
}

fn term(self: *Parser) ParseError!*Expression {
    var expr = try self.factor();
    while (self.match(&[_]TokenType{ .MINUS, .PLUS })) {
        const operator = self.previous();
        const right = try self.factor();
        const binary_expr = try self.allocator.create(Expression);
        binary_expr.* = Expression{
            .binary = Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            },
        };
        expr = binary_expr;
    }
    return expr;
}

fn factor(self: *Parser) ParseError!*Expression {
    var expr = try self.unary();
    while (self.match(&[_]TokenType{ .SLASH, .STAR })) {
        const operator = self.previous();
        const right = try self.unary();
        const binary_expr = try self.allocator.create(Expression);
        binary_expr.* = Expression{
            .binary = Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            },
        };
        expr = binary_expr;
    }
    return expr;
}

fn unary(self: *Parser) ParseError!*Expression {
    if (self.match(&[_]TokenType{ .BANG, .MINUS })) {
        const operator = self.previous();
        const right = try self.unary();
        const unary_expr = try self.allocator.create(Expression);
        unary_expr.* = Expression{
            .unary = Unary{
                .operator = operator,
                .right = right,
            },
        };
        return unary_expr;
    }
    return try self.primary();
}

fn comparison(self: *Parser) ParseError!*Expression {
    var expr = try self.term();
    while (self.match(&[_]TokenType{ .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL })) {
        const operator = self.previous();
        const right = try self.term();
        const binary_expr = try self.allocator.create(Expression);
        binary_expr.* = Expression{
            .binary = Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            },
        };
        expr = binary_expr;
    }
    return expr;
}

fn primary(self: *Parser) ParseError!*Expression {
    if (self.match(&[_]TokenType{.FALSE})) {
        const literal_expr = try self.allocator.create(Expression);
        literal_expr.* = Expression{
            .literal = Literal{
                .bool = false,
            },
        };
        return literal_expr;
    }
    if (self.match(&[_]TokenType{.TRUE})) {
        const literal_expr = try self.allocator.create(Expression);
        literal_expr.* = Expression{
            .literal = Literal{
                .bool = true,
            } ,
        };
        return literal_expr;
    }
    if (self.match(&[_]TokenType{.NIL})) {
        const literal_expr = try self.allocator.create(Expression);
        literal_expr.* = Expression{
            .literal = Literal{
                .nil = {},
            },
        };
        return literal_expr;
    }

    if (self.match(&[_]TokenType{.NUMBER})) {
        const num = std.fmt.parseFloat(f64, self.previous().lexeme) catch {
            std.debug.print("Failed to parse float: {s}\n", .{self.previous().lexeme});
            return ParseError.ExpectedExpression;
        };
        const literal_expr = try self.allocator.create(Expression);
        literal_expr.* = Expression{
            .literal = Literal{
                .number = num,
            },
        };
        return literal_expr;
    }

    if (self.match(&[_]TokenType{.LEFT_PAREN})) {
        const expr = try self.expression();
        _ = try self.consume(.RIGHT_PAREN, "Expect ')' after expression.");
        const grouping_expr = try self.allocator.create(Expression);
        grouping_expr.* = Expression{
            .grouping = Grouping{
                .expression = expr,
            },
        };
        return grouping_expr;
    }

    std.debug.print("Parse error at token: {s}\n", .{self.peek().lexeme});
    return ParseError.ExpectedExpression;
}

fn consume(self: *Parser, ttype: TokenType, message: []const u8) ParseError!Token {
    if (self.check(ttype)) {
        return self.advance();
    }
    std.debug.print("Consume error: {s} at token {s}\n", .{ message, self.peek().lexeme });
    if (ttype == .RIGHT_PAREN) return ParseError.ExpectedRightParen;
    return ParseError.ExpectedExpression;
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

fn match(self: *Parser, ttypes: []const TokenType) bool {
    for (ttypes) |ttype| {
        if (self.check(ttype)) {
            _ = self.advance();
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
    return self.tokens.items[self.current];
}

fn previous(self: *Parser) Token {
    return self.tokens.items[self.current - 1];
}
