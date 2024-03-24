const std = @import("std");

var IS_TESTING: bool = false;

const VMError = error{
    StackUnderflow,
    DecodeError,
    UnknownRegister,
    CodeOverflow,
    InvalidBinaryFormat,
    InvalidBinaryVersion,
    InvalidBytecode,
    InvalidArguments,
    TypeError,
    IllegalInstruction,
    ZeroDivisionError,
    ImplicitReturn,
};

const VMType = enum {
    uint,
    int,
    bool,

    pub fn from_byte(byte: u8) VMError!VMType {
        return switch (byte) {
            0 => .uint,
            1 => .int,
            2 => .bool,
            else => VMError.InvalidBytecode,
        };
    }
};

const VMValue = struct {
    type: VMType,
    value: union { int: i64, uint: u64, bool: bool },

    pub fn from_u64(value: u64) VMValue {
        return VMValue{ .type = VMType.uint, .value = .{ .uint = value } };
    }

    pub fn from_i64(value: i64) VMValue {
        return VMValue{ .type = VMType.int, .value = .{ .int = value } };
    }

    pub fn to_u64(self: VMValue) !u64 {
        if (self.type != VMType.uint) {
            return VMError.TypeError;
        } else {
            return self.value.uint;
        }
    }

    pub fn to_i64(self: VMValue) !i64 {
        if (self.type != VMType.int) {
            return VMError.TypeError;
        } else {
            return self.value.int;
        }
    }

    pub fn add(self: VMValue, other: VMValue) !VMValue {
        if (self.type != other.type) {
            return VMError.TypeError;
        }
        var result = self;
        switch (result.type) {
            .uint => {
                result.value.uint += other.value.uint;
            },
            .int => {
                result.value.int += other.value.int;
            },
            else => return VMError.TypeError,
        }
        return result;
    }

    pub fn sub(self: VMValue, other: VMValue) !VMValue {
        if (self.type != other.type) {
            return VMError.TypeError;
        }
        var result = self;
        switch (result.type) {
            .uint => {
                result.value.uint -= other.value.uint;
            },
            .int => {
                result.value.int -= other.value.int;
            },
            else => return VMError.TypeError,
        }
        return result;
    }

    pub fn mul(self: VMValue, other: VMValue) !VMValue {
        if (self.type != other.type) {
            return VMError.TypeError;
        }
        var result = self;
        switch (result.type) {
            .uint => {
                result.value.uint *= other.value.uint;
            },
            .int => {
                result.value.int *= other.value.int;
            },
            else => return VMError.TypeError,
        }
        return result;
    }

    pub fn div(self: VMValue, other: VMValue) !VMValue {
        if (self.type != other.type) {
            return VMError.TypeError;
        }
        var result = self;
        switch (result.type) {
            .uint => {
                if (other.value.uint == 0) return VMError.ZeroDivisionError;
                result.value.uint = @divExact(result.value.uint, other.value.uint);
            },
            .int => {
                if (other.value.int == 0) return VMError.ZeroDivisionError;
                result.value.int = @divExact(result.value.int, other.value.int);
            },
            else => return VMError.TypeError,
        }
        return result;
    }
};
test "VMValue.from_u64" {
    const val = 694200198;
    const vmv = VMValue.from_u64(val);
    try std.testing.expect(vmv.type == VMType.uint);
    try std.testing.expect(vmv.value.uint == val);
}

const VMOpType = enum(u16) {
    Nop,
    Push,
    Add,
    Sub,
    Mul,
    Div,
    Dup,
    Ret,
    _,
};

const VMInstruction = struct {
    type: VMOpType,
    operand: ?VMValue,

    pub fn nop() VMInstruction {
        return VMInstruction{ .type = .Nop, .operand = null };
    }

    pub fn push(operand: VMValue) VMInstruction {
        return VMInstruction{ .type = .Push, .operand = operand };
    }

    pub fn add() VMInstruction {
        return VMInstruction{ .type = .Add, .operand = null };
    }

    pub fn sub() VMInstruction {
        return VMInstruction{ .type = .Sub, .operand = null };
    }

    pub fn mul() VMInstruction {
        return VMInstruction{ .type = .Mul, .operand = null };
    }

    pub fn div() VMInstruction {
        return VMInstruction{ .type = .Div, .operand = null };
    }

    pub fn dup(operand: VMValue) VMInstruction {
        return VMInstruction{ .type = .Dup, .operand = operand };
    }

    pub fn ret() VMInstruction {
        return VMInstruction{ .type = .Ret, .operand = null };
    }
};

const Function = struct {
    // func_sz: u64,
    name: []u8,
    // arg_c: u64,
    args: []VMType,
    // ret_c: u64,
    rets: []VMType,
    // code_sz: u64,
    code: []u8,

    _allocator: std.mem.Allocator,
    _decoded: ?[]VMInstruction,

    pub fn from_bytes(bytes: []u8, allocator: std.mem.Allocator) !Function {
        var ip: u64 = @sizeOf(u64);
        const name_sz = std.mem.readIntSliceLittle(u64, bytes[0..@sizeOf(u64)]);
        var name = bytes[ip .. ip + name_sz];
        ip += name_sz;

        const args_sz = std.mem.readIntSliceLittle(u64, bytes[ip .. ip + @sizeOf(u64)]);
        ip += @sizeOf(u64);
        var args: []VMType = try allocator.alloc(VMType, args_sz);
        var processed_args: u64 = 0;
        while (processed_args < args_sz) {
            args[processed_args] = try VMType.from_byte(bytes[ip]);
            ip += 1;
            processed_args += 1;
        }

        const rets_sz = std.mem.readIntSliceLittle(u64, bytes[ip .. ip + @sizeOf(u64)]);
        ip += @sizeOf(u64);

        var rets: []VMType = try allocator.alloc(VMType, rets_sz);
        var processed_rets: u64 = 0;
        while (processed_rets < rets_sz) {
            rets[processed_rets] = try VMType.from_byte(bytes[ip]);
            ip += 1;
            processed_rets += 1;
        }

        const code_sz = std.mem.readIntSliceLittle(u64, bytes[ip .. ip + @sizeOf(u64)]);
        ip += @sizeOf(u64);
        var code: []u8 = try allocator.alloc(u8, code_sz);
        std.mem.copy(u8, code, bytes[ip .. ip + code_sz]);

        if (IS_TESTING) {
            std.log.debug("func {s}", .{name});
            for (args) |arg| {
                std.log.debug("< {d}", .{@intFromEnum(arg)});
            }
            for (rets) |ret| {
                std.log.debug("> {d}", .{@intFromEnum(ret)});
            }
            std.log.debug("= {d}", .{code.len});
        }

        return Function{ .name = name, .args = args, .rets = rets, .code = code, ._allocator = allocator, ._decoded = null };
    }

    pub fn deinit(self: *const Function) void {
        self._allocator.free(self.rets);
        self._allocator.free(self.args);
        self._allocator.free(self.code);
        if (self._decoded) |d| {
            self._allocator.free(d);
        }
    }

    pub fn decode(self: *Function) ![]VMInstruction {
        return self._decoded orelse {
            var ip: u64 = 0;
            var _decoded = std.ArrayList(VMInstruction).init(self._allocator);
            defer _decoded.deinit();
            while (ip < self.code.len) {
                try _decoded.append(switch (self.code[ip]) {
                    0 => VMInstruction.nop(),
                    1 => blk: { // push <type> (value)
                        ip += 1;
                        const t = try VMType.from_byte(self.code[ip - 1]);
                        var v: VMValue = undefined;
                        if (t == .uint) {
                            ip += 8;
                            v = VMValue{ .type = t, .value = .{ .uint = std.mem.readIntSliceLittle(u64, self.code[ip - 8 .. ip]) } };
                        } else if (t == .int) {
                            ip += 8;
                            v = VMValue{ .type = t, .value = .{ .int = std.mem.readIntSliceLittle(i64, self.code[ip - 8 .. ip]) } };
                        } else if (t == .bool) {
                            ip += 1;
                            v = VMValue{ .type = t, .value = .{ .bool = (self.code[ip - 1] != 0) } };
                        }
                        break :blk VMInstruction.push(v);
                    },
                    2 => VMInstruction.add(),
                    3 => VMInstruction.sub(),
                    4 => VMInstruction.mul(),
                    5 => VMInstruction.div(),
                    6 => blk: { // dup (offset)
                        ip += 8;
                        const offset = std.mem.readIntSliceLittle(u64, self.code[ip - 8 .. ip]);
                        break :blk VMInstruction.dup(VMValue.from_u64(offset));
                    },
                    7 => VMInstruction.ret(),
                    else => return VMError.InvalidBytecode,
                });
                ip += 1;
            }
            self._decoded = try _decoded.toOwnedSlice();
            if (self._decoded) |a| {
                return a;
            } else unreachable;
        };
    }

    pub fn exec(self: *Function, args: []VMValue) ![]VMValue {
        // type checking
        for (self.args, args) |_type, _arg| {
            if (_type != _arg.type) {
                std.log.err("invalid arguments found", .{});
                return VMError.InvalidArguments;
            }
        }

        std.log.info("arguments checked", .{});

        var stack = std.ArrayList(VMValue).init(self._allocator);
        defer stack.deinit();

        for (args) |arg| {
            std.log.info("stack.append({any})", .{arg});
            try stack.append(arg);
        }

        const code = try self.decode();

        var ip: u64 = 0;
        while (ip < code.len) {
            switch (code[ip].type) {
                .Nop => ip += 1,
                .Push => {
                    try stack.append(code[ip].operand.?);
                    ip += 1;
                },
                .Add, .Sub, .Mul, .Div => {
                    std.log.info("stack.len = {d}", .{stack.items.len});
                    const b_v = stack.pop();
                    const a_v = stack.pop();

                    try stack.append(switch (code[ip].type) {
                        .Add => try a_v.add(b_v),
                        .Sub => try a_v.sub(b_v),
                        .Mul => try a_v.mul(b_v),
                        .Div => try a_v.div(b_v),
                        else => unreachable,
                    });
                    ip += 1;
                },
                .Dup => {
                    try stack.append(stack.items[stack.items.len - 1 - try code[ip].operand.?.to_u64()]);
                    ip += 1;
                },
                .Ret => {
                    const rets = try stack.toOwnedSlice();
                    for (self.rets, rets) |_type, _ret| {
                        if (_type != _ret.type) {
                            return VMError.InvalidArguments;
                        }
                    }
                    return rets;
                },

                else => return VMError.IllegalInstruction,
            }
        }

        return VMError.ImplicitReturn;
    }
};

const Binary = struct {
    // magic: [4]u8, // = "cbvm"
    // version: u8, // = 0
    // function_c: u64
    functions: []Function,

    _allocator: std.mem.Allocator,

    pub fn from_bytes(bytes: []u8, allocator: std.mem.Allocator) !Binary {
        const min_sz = 5 + @sizeOf(u64);
        if (bytes.len < min_sz) {
            return VMError.InvalidBinaryFormat;
        }

        const magic = bytes[0..4];
        if (!std.mem.eql(u8, magic, "cbvm")) {
            return VMError.InvalidBinaryFormat;
        }

        const version = bytes[4];
        if (version != 0) {
            return VMError.InvalidBinaryVersion;
        }

        const function_c = std.mem.readIntSliceLittle(u64, bytes[5 .. 5 + @sizeOf(u64)]);
        var ip: u64 = 5 + @sizeOf(u64);

        var functions = try allocator.alloc(Function, function_c);
        var processed_funcs: u64 = 0;
        while (processed_funcs < function_c) {
            const fn_sz = std.mem.readIntSliceLittle(u64, bytes[ip .. ip + @sizeOf(u64)]);
            ip += @sizeOf(u64);
            functions[processed_funcs] = (try Function.from_bytes(bytes[ip .. ip + fn_sz], allocator));
            processed_funcs += 1;
            ip += fn_sz;
        }

        return Binary{ .functions = functions, ._allocator = allocator };
    }

    pub fn deinit(self: *Binary) void {
        for (self.functions) |i| {
            i.deinit();
        }

        self._allocator.free(self.functions);
    }
};

fn read_file(path: [:0]const u8, allocator: std.mem.Allocator) ![]u8 {
    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const realpath = try std.fs.realpath(path, &path_buffer);

    const file = try std.fs.openFileAbsolute(realpath, .{});
    defer file.close();

    return try file.readToEndAlloc(allocator, std.math.maxInt(u64));
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
        // .verbose_log = true,
    }){};
    // TODO: fix memory leaks
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var argv = std.process.args();
    defer argv.deinit();

    const program = argv.next().?;
    // defer allocator.free(program);

    const file_path = argv.next() orelse {
        std.log.err("expected input file argument.", .{});
        std.log.info("usage: {s} <file>", .{program});
        return;
    };

    if (argv.next()) |flag| {
        if (std.mem.eql(u8, flag, "--test")) {
            IS_TESTING = true;
        }
    }

    const file = try read_file(file_path, allocator);
    defer allocator.free(file);

    var bin = try Binary.from_bytes(file, allocator);
    defer bin.deinit();

    if (!IS_TESTING) {
        var func = bin.functions[0];
        std.log.debug("{s}(...)", .{func.name});
        var args = [_]VMValue{ VMValue.from_i64(420), VMValue.from_i64(69) };
        const result = try func.exec(&args);
        std.log.debug("add(420i, 69i) -> {d}", .{try result[0].to_i64()});
    }
}
