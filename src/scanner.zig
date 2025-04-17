const std = @import("std");

const Scanner = @This();

source: []const u8,
tokens: std.ArrayList(Token),
start: usize,
current: usize,
line: usize,

pub fn init(allocator: std.mem.Allocator, source: []const u8) Scanner {
    return Scanner{
        .source = source,
        .tokens = std.ArrayList(Token).init(allocator),
        .start = 0,
        .current = 0,
        .line = 1,
    };
}

fn isAtEnd(self: *Scanner) bool {
    return self.current >= self.source.len;
}

fn peek(self: *Scanner) u8 {
    if (self.isAtEnd()) {
        return 0;
    }
    return self.source[self.current];
}

fn advance(self: *Scanner) void {
    self.current += 1;
}

pub fn makeError(self: *Scanner, message: []const u8) Token {
    return Token{
        .ttype = .ERROR,
        .lexeme = message,
        .line = self.line,
    };
}

fn makeToken(self: *Scanner, ttype: TokenType) Token {
    return Token{
        .ttype = ttype,
        .lexeme = self.source[self.start..self.current],
        .line = self.line,
    };
}

fn match(self: *Scanner, expected: u8) bool {
    if (self.isAtEnd()) {
        return false;
    }
    if (self.source[self.current] != expected) {
        return false;
    }

    self.current += 1;
    return true;
}

fn scanToken(self: *Scanner) Token {
    self.start = self.current;
    if (self.isAtEnd()) {
        return self.makeToken(.EOF);
    }

    const c = self.peek();
    self.advance();

    return switch (c) {
        '(' => self.makeToken(.LEFT_PAREN),
        ')' => self.makeToken(.RIGHT_PAREN),
        '{' => self.makeToken(.LEFT_BRACE),
        '}' => self.makeToken(.RIGHT_BRACE),
        ',' => self.makeToken(.COMMA),
        '.' => self.makeToken(.DOT),
        '-' => self.makeToken(.MINUS),
        '+' => self.makeToken(.PLUS),
        ';' => self.makeToken(.SEMICOLON),
        '*' => self.makeToken(.STAR),
        '!' => self.makeToken(if (match('=')) .BANG_EQUAL else .BANG),
        '=' => self.makeToken(if (match('=')) .EQUAL_EQUAL else .EQUAL),
        '<' => self.makeToken(if (match('=')) .LESS_EQUAL else .LESS),
        '>' => self.makeToken(if (match('=')) .GREATER_EQUAL else .GREATER),
        else => {
            return self.makeError("Unexpected character");
        },
    };
}

pub fn scanTokens(self: *Scanner) !std.ArrayList(Token) {
    while (!self.isAtEnd()) {
        try self.tokens.append(self.scanToken());
    }
    return self.tokens;
}

pub const Token = struct {
    ttype: TokenType,
    lexeme: []const u8,
    line: usize,
};

pub const TokenType = enum {
    // Single-character tokens.
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,

    // One or two character tokens.
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,

    // Literals.
    IDENTIFIER,
    STRING,
    NUMBER,

    // Keywords.
    AND,
    CLASS,
    ELSE,
    FALSE,
    FUN,
    FOR,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,

    ERROR,
    EOF,
};
