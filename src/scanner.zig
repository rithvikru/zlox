const std = @import("std");

const Scanner = @This();

source: []const u8,
tokens: std.ArrayList(Token),
start: usize,
current: usize,
line: usize,
keywords: std.StaticStringMap(TokenType) = std.StaticStringMap(TokenType).initComptime(.{
    .{ "and", .AND },
    .{ "class", .CLASS },
    .{ "else", .ELSE },
    .{ "false", .FALSE },
    .{ "for", .FOR },
    .{ "fun", .FUN },
    .{ "if", .IF },
    .{ "nil", .NIL },
    .{ "or", .OR },
    .{ "print", .PRINT },
    .{ "return", .RETURN },
    .{ "super", .SUPER },
    .{ "this", .THIS },
    .{ "true", .TRUE },
    .{ "var", .VAR },
    .{ "while", .WHILE },
}),

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

fn peekNext(self: *Scanner) u8 {
    if (self.current + 1 >= self.source.len) {
        return 0;
    }
    return self.source[self.current + 1];
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

fn skipWhitespace(self: *Scanner) void {
    while (true) {
        switch (self.peek()) {
            ' ', '\r', '\t' => self.advance(),
            '\n' => {
                self.line += 1;
                self.advance();
            },
            '/' => {
                if (self.match('/')) {
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        self.advance();
                    }
                } else {
                    return;
                }
            },
            else => return,
        }
    }
}

fn scanString(self: *Scanner) Token {
    while (self.peek() != '"' and !self.isAtEnd()) {
        if (self.peek() == '\n') {
            self.line += 1;
        }
        self.advance();
    }

    if (self.isAtEnd()) {
        return self.makeError("Unterminated string.");
    }

    self.advance();

    return self.makeToken(.STRING);
}

fn scanNumber(self: *Scanner) Token {
    while (isDigit(self.peek())) {
        self.advance();
    }

    if (self.peek() == '.' and isDigit(self.peekNext())) {
        self.advance();
        while (isDigit(self.peek())) {
            self.advance();
        }
    }

    return self.makeToken(.NUMBER);
}

fn scanIdentifier(self: *Scanner) Token {
    while (isAlphaNumeric(self.peek())) {
        self.advance();
    }

    const text = self.source[self.start..self.current];
    const ttype = self.keywords.get(text);

    return self.makeToken(ttype orelse .IDENTIFIER);
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn isAlphaNumeric(c: u8) bool {
    return isAlpha(c) or isDigit(c);
}

fn scanToken(self: *Scanner) Token {
    self.skipWhitespace();

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
        '/' => self.makeToken(.SLASH),
        '!' => self.makeToken(if (self.match('=')) .BANG_EQUAL else .BANG),
        '=' => self.makeToken(if (self.match('=')) .EQUAL_EQUAL else .EQUAL),
        '<' => self.makeToken(if (self.match('=')) .LESS_EQUAL else .LESS),
        '>' => self.makeToken(if (self.match('=')) .GREATER_EQUAL else .GREATER),
        '"' => self.scanString(),
        else => {
            if (isDigit(self.peek())) return self.scanNumber();
            if (isAlpha(self.peek())) return self.scanIdentifier();
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
