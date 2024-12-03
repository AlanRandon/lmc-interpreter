const std = @import("std");
const lmc = @import("./lmc.zig");
const Allocator = std.mem.Allocator;

pub const StepResult = enum {
    halt,
    @"continue",
};

pub const Interpreter = struct {
    program_counter: usize = 0,
    accumulator: lmc.Inst = 0,
    memory: *lmc.Memory,

    const Self = @This();

    pub fn step(interpreter: *Self, io: anytype) !StepResult {
        const inst = interpreter.memory[interpreter.program_counter];
        interpreter.program_counter += 1;

        const addr: usize = @intCast(@mod(inst, 100));

        switch (@divFloor(inst, 100)) {
            1 => interpreter.accumulator += interpreter.memory[addr],
            2 => interpreter.accumulator -= interpreter.memory[addr],
            3 => interpreter.memory[addr] = interpreter.accumulator,
            5 => interpreter.accumulator = interpreter.memory[addr],
            6 => interpreter.program_counter = @intCast(addr),
            7 => if (interpreter.accumulator == 0) {
                interpreter.program_counter = @intCast(addr);
            },
            8 => if (interpreter.accumulator >= 0) {
                interpreter.program_counter = @intCast(addr);
            },
            else => switch (inst) {
                0 => return .halt,
                901 => interpreter.accumulator = try io.read(),
                902 => try io.write(interpreter.accumulator),
                else => return error.UnknownInstruction,
            },
        }

        return .@"continue";
    }
};

pub const Io = struct {
    in: std.io.AnyReader,
    out: std.io.AnyWriter,
    allocator: Allocator,

    fn read(io: *Io) !lmc.Inst {
        try io.out.writeAll("input required: ");
        var line = std.ArrayList(u8).init(io.allocator);
        defer line.deinit();
        try io.in.streamUntilDelimiter(line.writer(), '\n', null);
        return std.fmt.parseInt(lmc.Inst, line.items, 10) catch {
            try io.out.print("malformed integer entered\n", .{});
            return try io.read();
        };
    }

    fn write(io: *Io, n: lmc.Inst) !void {
        try io.out.print("{}\n", .{n});
    }
};

const usage = "USAGE: lmc-interpreter INPUT\n";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var memory = std.mem.zeroes(lmc.Memory);

    const stdout = std.io.getStdOut().writer();

    var args = std.process.args();
    defer args.deinit();
    _ = args.next();

    const path = if (args.next()) |arg| @as([]const u8, arg) else {
        try stdout.writeAll(usage);
        return;
    };

    if (args.next() != null) {
        try stdout.writeAll(usage);
        return;
    }

    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    for (&memory) |*inst| {
        inst.* = try file.reader().readInt(lmc.Inst, .big);
    }

    var io = Io{
        .in = std.io.getStdIn().reader().any(),
        .out = stdout.any(),
        .allocator = allocator,
    };

    var interpreter = Interpreter{ .memory = &memory };

    while (try interpreter.step(&io) != .halt) {}
}
