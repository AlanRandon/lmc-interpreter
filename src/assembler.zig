const std = @import("std");
const lmc = @import("./lmc.zig");
const Inst = lmc.Inst;
const Allocator = std.mem.Allocator;

pub const Token = union(enum) {
    newline,
    ident: []const u8,
    literal: Address,
    load,
    store,
    add,
    subtract,
    input,
    output,
    end,
    branch_if_zero,
    branch_if_zero_or_positive,
    branch_always,
    data_location,
};

pub const Tokenizer = struct {
    buf: []const u8,

    pub fn init(buf: []const u8) Tokenizer {
        return .{ .buf = buf };
    }

    pub fn peekChar(tokenizer: *Tokenizer) ?u8 {
        return if (tokenizer.buf.len > 0) tokenizer.buf[0] else null;
    }

    pub fn takeChar(tokenizer: *Tokenizer) ?u8 {
        const ch = tokenizer.peekChar() orelse return null;
        tokenizer.buf = tokenizer.buf[1..];
        return ch;
    }

    pub fn takeToken(tokenizer: *Tokenizer) !?Token {
        const buf = tokenizer.buf;
        errdefer tokenizer.buf = buf;

        var ch = tokenizer.takeChar() orelse return null;

        if (ch == '\n') {
            return .newline;
        }

        if (ch == '/' and tokenizer.peekChar() == '/') {
            while (ch != '\n') {
                ch = tokenizer.takeChar() orelse return null;
            }
        }

        if (std.ascii.isWhitespace(ch)) {
            return try tokenizer.takeToken();
        }

        if (std.ascii.isAlphabetic(ch)) {
            var len: usize = 1;
            if (tokenizer.peekChar()) |peek| {
                ch = peek;
                while (std.ascii.isAlphanumeric(ch)) {
                    _ = tokenizer.takeChar();
                    len += 1;
                    ch = tokenizer.peekChar() orelse break;
                }
            }

            const ident = buf[0..len];

            if (std.mem.eql(u8, ident, "LDA")) {
                return .load;
            } else if (std.mem.eql(u8, ident, "STA")) {
                return .store;
            } else if (std.mem.eql(u8, ident, "ADD")) {
                return .add;
            } else if (std.mem.eql(u8, ident, "SUB")) {
                return .subtract;
            } else if (std.mem.eql(u8, ident, "INP")) {
                return .input;
            } else if (std.mem.eql(u8, ident, "OUT")) {
                return .output;
            } else if (std.mem.eql(u8, ident, "HLT")) {
                return .end;
            } else if (std.mem.eql(u8, ident, "BRZ")) {
                return .branch_if_zero;
            } else if (std.mem.eql(u8, ident, "BRP")) {
                return .branch_if_zero_or_positive;
            } else if (std.mem.eql(u8, ident, "BRA")) {
                return .branch_always;
            } else if (std.mem.eql(u8, ident, "DAT")) {
                return .data_location;
            } else {
                return .{ .ident = ident };
            }
        }

        while (std.ascii.isDigit(ch) or ch == '-') {
            var len: usize = 1;
            if (tokenizer.peekChar()) |peek| {
                ch = peek;
                while (std.ascii.isDigit(ch)) {
                    _ = tokenizer.takeChar();
                    len += 1;
                    ch = tokenizer.peekChar() orelse break;
                }
            }

            return .{ .literal = std.fmt.parseInt(Address, buf[0..len], 10) catch return error.MalformedInteger };
        }

        return error.UnexpectedCharacter;
    }

    pub const TokenList = std.ArrayList(Token);
    pub fn tokenize(tokenizer: *Tokenizer, allocator: Allocator) !TokenList {
        var list = TokenList.init(allocator);

        while (try tokenizer.takeToken()) |token| {
            try list.append(token);
        }

        return list;
    }
};

pub const Address = Inst;

pub const Assembler = struct {
    tokens: []Token,

    pub fn init(tokens: []Token) Assembler {
        return .{
            .tokens = tokens,
        };
    }

    pub fn peekToken(assember: *Assembler) ?Token {
        return if (assember.tokens.len == 0) null else assember.tokens[0];
    }

    pub fn takeToken(assember: *Assembler) ?Token {
        const tok = assember.peekToken() orelse return null;
        assember.tokens = assember.tokens[1..];
        return tok;
    }

    const UnresolvedAddress = union(enum) {
        literal: Address,
        label: []const u8,

        fn resolve(address: *const UnresolvedAddress, labels: *const std.StringHashMap(Address)) !Address {
            return switch (address.*) {
                .literal => |literal| literal,
                .label => |label| labels.get(label) orelse return error.UnknownLabel,
            };
        }
    };

    pub fn takeUnresolvedAddress(assembler: *Assembler) !UnresolvedAddress {
        return switch (assembler.takeToken() orelse return error.MissingAddress) {
            .ident => |ident| .{ .label = ident },
            .literal => |literal| .{ .literal = literal },
            else => error.MissingAddress,
        };
    }

    pub fn assemble(assembler: *Assembler, allocator: Allocator) !lmc.Memory {
        var labels = std.StringHashMap(Address).init(allocator);
        defer labels.deinit();

        var unresolved_insts = std.ArrayList(union(enum) {
            load: UnresolvedAddress,
            store: UnresolvedAddress,
            add: UnresolvedAddress,
            subtract: UnresolvedAddress,
            input,
            output,
            end,
            branch_if_zero: UnresolvedAddress,
            branch_if_zero_or_positive: UnresolvedAddress,
            branch_always: UnresolvedAddress,
            data_location: ?UnresolvedAddress,
        }).init(allocator);
        defer unresolved_insts.deinit();

        while (assembler.takeToken()) |token| {
            switch (token) {
                .newline => {},
                .ident => |ident| {
                    try labels.put(ident, @intCast(unresolved_insts.items.len));
                },
                .literal => return error.UnexpectedLiteral,
                .end => try unresolved_insts.append(.end),
                .load => try unresolved_insts.append(.{ .load = try assembler.takeUnresolvedAddress() }),
                .store => try unresolved_insts.append(.{ .store = try assembler.takeUnresolvedAddress() }),
                .add => try unresolved_insts.append(.{ .add = try assembler.takeUnresolvedAddress() }),
                .subtract => try unresolved_insts.append(.{ .subtract = try assembler.takeUnresolvedAddress() }),
                .input => try unresolved_insts.append(.input),
                .output => try unresolved_insts.append(.output),
                .branch_if_zero => try unresolved_insts.append(.{ .branch_if_zero = try assembler.takeUnresolvedAddress() }),
                .branch_if_zero_or_positive => try unresolved_insts.append(.{ .branch_if_zero_or_positive = try assembler.takeUnresolvedAddress() }),
                .branch_always => try unresolved_insts.append(.{ .branch_always = try assembler.takeUnresolvedAddress() }),
                .data_location => try unresolved_insts.append(.{ .data_location = assembler.takeUnresolvedAddress() catch |err| switch (err) {
                    error.MissingAddress => null,
                    else => return err,
                } }),
            }
        }

        var memory = std.mem.zeroes(lmc.Memory);
        for (unresolved_insts.items, 0..) |inst, i| {
            memory[i] = switch (inst) {
                .end => 0,
                .add => |addr| 100 + try addr.resolve(&labels),
                .subtract => |addr| 200 + try addr.resolve(&labels),
                .store => |addr| 300 + try addr.resolve(&labels),
                .load => |addr| 500 + try addr.resolve(&labels),
                .branch_always => |addr| 600 + try addr.resolve(&labels),
                .branch_if_zero => |addr| 700 + try addr.resolve(&labels),
                .branch_if_zero_or_positive => |addr| 800 + try addr.resolve(&labels),
                .input => 901,
                .output => 902,
                .data_location => |data| if (data) |d| try d.resolve(&labels) else 0,
            };
        }

        return memory;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const buf = try std.io.getStdIn().reader().readAllAlloc(allocator, 8128);
    defer allocator.free(buf);

    var tokenizer = Tokenizer.init(buf);
    const tokens = try tokenizer.tokenize(allocator);
    defer tokens.deinit();

    var assember = Assembler.init(tokens.items);
    const memory = try assember.assemble(allocator);

    const stdout = std.io.getStdOut().writer();
    for (memory) |inst| {
        try stdout.writeInt(Inst, inst, .big);
    }
}
