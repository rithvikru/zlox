const std = @import("std");
const Scanner = @import("scanner.zig");
const Token = @import("scanner.zig").Token;
const Parser = @import("parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    switch (args.len) {
        2 => try runFile(allocator, args[1]),
        else => {
            const stderr = std.io.getStdErr().writer();
            try stderr.print("Usage: zlox [path]\n", .{});
            std.process.exit(64);
        },
    }
}

fn runFile(allocator: std.mem.Allocator, path: []const u8) !void {
    const source = try std.fs.cwd().readFileAlloc(allocator, path, 1_000_000);
    defer allocator.free(source);
    try run(allocator, source);
}

fn run(allocator: std.mem.Allocator, source: []const u8) !void {
    var scanner = Scanner.init(allocator, source);
    const tokens = try scanner.scanTokens();
    // for (tokens.items) |token| {
    //     std.debug.print("[{}] {} [{s}]\n", .{ token.line, token.ttype, token.lexeme });
    // }
    var parser = Parser.init(allocator, tokens);
    const expression = parser.parse() catch |err| {
        std.debug.print("Parse error: {s}\n", .{@errorName(err)});
        std.process.exit(65);
    };

    std.debug.print("Parsed expression: {s}\n", .{expression});
}
