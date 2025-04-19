const std = @import("std");
const Token = @import("scanner.zig").Token;

pub const Binary = struct {
    left: *const Expression,
    operator: Token,
    right: *const Expression,
};

pub const Grouping = struct {
    expression: *const Expression,
};

pub const Literal = union(enum) {
    number: f64,
    bool: bool,
    nil: void,
};

pub const Unary = struct {
    operator: Token,
    right: *const Expression,
};

pub const Expression = union(enum) {
    binary: Binary,
    grouping: Grouping,
    literal: Literal,
    unary: Unary,

    pub fn format(self: Expression, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            .binary => |b| {
                try parenthesize(writer, b.operator.lexeme, .{ b.left, b.right });
            },
            .grouping => |g| {
                try parenthesize(writer, "group", .{g.expression});
            },
            .literal => |l| {
                try writer.print("{d}", .{l.value});
            },
            .unary => |u| {
                try parenthesize(writer, u.operator.lexeme, .{u.right});
            },
        }
    }

    fn parenthesize(writer: anytype, name: []const u8, expressions: anytype) !void {
        try writer.print("({s}", .{name});
        inline for (expressions) |e| {
            try writer.print(" {s}", .{e.*});
        }
        try writer.print(")", .{});
    }
};
