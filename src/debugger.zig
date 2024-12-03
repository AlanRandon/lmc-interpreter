const std = @import("std");
const assembler = @import("./assembler.zig");
const interpreter = @import("./interpreter.zig");
const lmc = @import("./lmc.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var memory = std.mem.zeroes(lmc.Memory);
    var interp = interpreter.Interpreter{ .memory = &memory };

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var io = interpreter.Io{
        .in = stdin.any(),
        .out = stdout.any(),
        .allocator = allocator,
    };

    while (true) {
        try stdout.writeAll("lmc-dbg> ");

        const line = stdin.readUntilDelimiterAlloc(allocator, '\n', 128) catch |err| switch (err) {
            error.StreamTooLong => {
                try stdout.writeAll("line too long");
                continue;
            },
            else => return err,
        };
        defer allocator.free(line);

        var line_tokenizer = std.mem.tokenizeAny(u8, line, " ");
        if (line_tokenizer.next()) |command| {
            if (std.mem.eql(u8, command, "quit") or std.mem.eql(u8, command, "q")) {
                if (line_tokenizer.next() != null) {
                    try stdout.print("unexpected args in quit: {s}\n", .{line});
                    continue;
                }
                break;
            } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "h")) {
                if (line_tokenizer.next() != null) {
                    try stdout.print("unexpected args in help: {s}\n", .{line});
                    continue;
                }

                try stdout.print(
                    \\COMMANDS:
                    \\
                    \\quit: quits the program
                    \\load FILENAME: loads and assembles a file into memory
                    \\mem: shows the memory
                    \\reg: shows the registers
                    \\step INSTRUCTIONS: runs until a halt is encountered or until a given number instructions (default 1) have been executed
                    \\run: runs until a halt is encountered
                    \\set REGISTER|MEMORY_ADDRESS VALUE: sets a register (pc or acc) or a memory address to a given value
                    \\reset: zeroes the memory and clears registers
                    \\help: shows this help
                    \\
                , .{});
            } else if (std.mem.eql(u8, command, "load") or std.mem.eql(u8, command, "l")) {
                if (line_tokenizer.next()) |path| {
                    if (line_tokenizer.next() != null) {
                        try stdout.print("unexpected args in load: {s}\n", .{line});
                        continue;
                    }

                    const file = std.fs.cwd().openFile(path, .{}) catch {
                        try stdout.print("failed to open file: {s}\n", .{path});
                        continue;
                    };
                    defer file.close();
                    const buf = try file.readToEndAlloc(allocator, 8128);
                    defer allocator.free(buf);

                    var tokenizer = assembler.Tokenizer.init(buf);
                    const tokens = tokenizer.tokenize(allocator) catch |err| switch (err) {
                        error.MalformedInteger => {
                            try stdout.print("malformed integer in assembly:\n{s}\n", .{buf});
                            continue;
                        },
                        error.UnexpectedCharacter => {
                            try stdout.print("unexpected character {} in assembly:\n{s}\n", .{ tokenizer.buf[0], buf });
                            continue;
                        },
                        error.OutOfMemory => return err,
                    };
                    defer tokens.deinit();

                    var assember = assembler.Assembler.init(tokens.items);
                    memory = assember.assemble(allocator) catch |err| switch (err) {
                        error.UnexpectedLiteral => {
                            try stdout.print("unexpected literal in assembly:\n{s}\n", .{buf});
                            continue;
                        },
                        error.MissingAddress => {
                            try stdout.print("missing address in assembly:\n{s}\n", .{buf});
                            continue;
                        },
                        error.UnknownLabel => {
                            try stdout.print("unknown label in assembly:\n{s}\n", .{buf});
                            continue;
                        },
                        error.OutOfMemory => return err,
                    };
                } else {
                    try stdout.print("load requires file path: {s}\n", .{line});
                }
            } else if (std.mem.eql(u8, command, "mem") or std.mem.eql(u8, command, "m")) {
                if (line_tokenizer.next() != null) {
                    try stdout.print("unexpected args in mem: {s}\n", .{line});
                    continue;
                }

                for (0..10) |i| {
                    for (0..10) |j| {
                        var buf = [_]u8{' '} ** 5;
                        _ = std.fmt.formatIntBuf(&buf, memory[10 * i + j], 10, .lower, .{});
                        try stdout.writeAll(&buf);
                    }
                    try stdout.writeAll("\n");
                }
            } else if (std.mem.eql(u8, command, "reset")) {
                if (line_tokenizer.next() != null) {
                    try stdout.print("unexpected args in reset: {s}\n", .{line});
                    continue;
                }

                memory = std.mem.zeroes(lmc.Memory);
                interp.program_counter = 0;
                interp.accumulator = 0;
            } else if (std.mem.eql(u8, command, "reg")) {
                if (line_tokenizer.next() != null) {
                    try stdout.print("unexpected args in reg: {s}\n", .{line});
                    continue;
                }

                try stdout.print("accumulator = {}\n", .{interp.accumulator});
                try stdout.print("program counter = {}\n", .{interp.program_counter});
            } else if (std.mem.eql(u8, command, "step") or std.mem.eql(u8, command, "s")) {
                const steps = if (line_tokenizer.next()) |token| std.fmt.parseInt(usize, token, 10) catch {
                    try stdout.print("malformed integer in step: {s}\n", .{line});
                    continue;
                } else 1;

                if (line_tokenizer.next() != null) {
                    try stdout.print("unexpected args in step: {s}\n", .{line});
                    continue;
                }

                for (0..steps) |_| {
                    const state = interp.step(&io) catch |err| switch (err) {
                        error.UnknownInstruction => {
                            try stdout.print("unknown instruction, halting: {}\n", .{interp.memory[interp.program_counter]});
                            break;
                        },
                        else => return err,
                    };

                    switch (state) {
                        .halt => {
                            std.debug.print("program halted\n", .{});
                            break;
                        },
                        .@"continue" => {},
                    }
                }
            } else if (std.mem.eql(u8, command, "run") or std.mem.eql(u8, command, "r")) {
                if (line_tokenizer.next() != null) {
                    try stdout.print("unexpected args in run: {s}\n", .{line});
                    continue;
                }

                while (true) {
                    const state = interp.step(&io) catch |err| switch (err) {
                        error.UnknownInstruction => {
                            try stdout.print("unknown instruction, halting: {}\n", .{interp.memory[interp.program_counter]});
                            break;
                        },
                        else => return err,
                    };

                    switch (state) {
                        .halt => {
                            std.debug.print("program halted\n", .{});
                            break;
                        },
                        .@"continue" => {},
                    }
                }
            } else if (std.mem.eql(u8, command, "set")) {
                const lhs = line_tokenizer.next() orelse {
                    try stdout.print("set missing lhs: {s}\n", .{line});
                    continue;
                };

                const rhs = if (line_tokenizer.next()) |token| std.fmt.parseInt(lmc.Inst, token, 10) catch {
                    try stdout.print("malformed set rhs: {s}\n", .{line});
                    continue;
                } else {
                    try stdout.print("set missing rhs: {s}\n", .{line});
                    continue;
                };

                if (line_tokenizer.next() != null) {
                    try stdout.print("unexpected args in set: {s}\n", .{line});
                    continue;
                }

                if (std.mem.eql(u8, lhs, "pc")) {
                    interp.program_counter = @intCast(rhs);
                } else if (std.mem.eql(u8, lhs, "acc")) {
                    interp.accumulator = @intCast(rhs);
                } else if (std.fmt.parseInt(usize, lhs, 10) catch null) |addr| {
                    interp.memory[addr] = @intCast(rhs);
                } else {
                    try stdout.print("malformed set lhs: {s}\n", .{line});
                }
            } else {
                try stdout.print("unknown command: {s}\n", .{line});
            }
        }
    }
}
