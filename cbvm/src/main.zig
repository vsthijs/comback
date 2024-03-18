const std = @import("std");

const VMError = error{
    StackUnderflow,
    DecodeError,
    UnknownRegister,
    CodeOverflow,
    InvalidBinaryFormat,
    InvalidBinaryVersion,
    InvalidBytecode,
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
    value: union { int: isize, uint: usize, bool: bool },

    pub fn from_usize(value: usize) VMValue {
        return VMValue{ .type = VMType.uint, .value = .{ .uint = value } };
    }
};
test "VMValue.from_usize" {
    const val = 694200198;
    const vmv = VMValue.from_usize(val);
    try std.testing.expect(vmv.type == VMType.uint);
    try std.testing.expect(vmv.value.uint == val);
}

const VMInstruction = struct {
    type: enum(u16) {
        Hlt,
        Push,
        Load,
        Store,
        _,
    },
    operand: usize,

    pub fn hlt() VMInstruction {
        return VMInstruction{ .type = .Hlt };
    }

    pub fn push(operand: usize) VMInstruction {
        return VMInstruction{ .type = .Push, .operand = operand };
    }

    pub fn load(operand: usize) VMError!VMInstruction {
        if (operand < 32) {
            return VMInstruction{ .type = .Load, .operand = operand };
        } else {
            return VMError.UnknownRegister;
        }
    }

    pub fn store(operand: usize) VMError!VMInstruction {
        if (operand < 32) {
            return VMInstruction{ .type = .Store, .operand = operand };
        } else {
            return VMError.UnknownRegister;
        }
    }
};

const VMContext = struct {
    allocator: std.heap.ArenaAllocator,
    heap: std.mem.Allocator,
    stack: std.ArrayList(VMValue),
    code: []u8,
    registers: [32]VMValue,

    _ip: usize,

    pub fn new(code: []u8) VMContext {
        var allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var heap = allocator.allocator();
        var stack = std.ArrayList(VMValue).init(heap);
        return VMContext{ .allocator = allocator, .heap = heap, .stack = stack, .code = code, .registers = undefined, ._ip = 0 };
    }

    pub fn deinit(self: *VMContext) void {
        self.stack.deinit();
        self.allocator.deinit();
    }

    pub fn push(self: *VMContext, value: VMValue) !void {
        // std.debug.print("push <- {}\n", .{value});
        try self.stack.append(value);
    }

    pub fn pop(self: *VMContext) VMError!VMValue {
        var val = self.stack.popOrNull();
        if (val == null) {
            return VMError.StackUnderflow;
        } else {
            // std.debug.print("pop -> {}\n", .{val.?});
            return val.?;
        }
    }

    fn read_int(self: *VMContext, sz: type) VMError!sz {
        if (self._ip + @sizeOf(sz) < self.code.len) {
            self._ip += @sizeOf(sz);
            return std.mem.readIntSliceLittle(sz, self.code[self._ip - @sizeOf(sz) .. self._ip]);
        } else {
            return VMError.CodeOverflow;
        }
    }

    pub fn decode(self: *VMContext) VMError!VMInstruction {
        const op = try self.read_int(u16);
        return switch (op) {
            0 => VMInstruction.hlt(),
            1 => VMInstruction.push(self.read_int(usize)),
            2 => VMInstruction.load(self.read_int(u8)),
            3 => VMInstruction.store(self.read_int(u8)),
            else => VMError.DecodeError,
        };
    }

    pub fn execute(self: *VMContext, instruction: VMInstruction) void {
        switch (instruction.type) {
            .Hlt => {},
            .Push => self.push(VMValue.from_usize(instruction.operand)),
            .Load => self.push(self.registers[instruction.operand]),
            .Store => self.registers[instruction.operand] = try self.pop(),
        }
    }
};

test "VMContext stack" {
    var buf = [0]u8{};
    var vm = VMContext.new(&buf);
    defer vm.deinit();
    try vm.push(VMValue.from_usize(69));
    var val = try vm.pop();
    try std.testing.expect(val.value.uint == 69);
}

const Function = struct {
    // func_sz: usize,
    name: []u8,
    // arg_c: usize,
    args: []VMType,
    // ret_c: usize,
    rets: []VMType,
    // code_sz: usize,
    code: []u8,

    _allocator: std.mem.Allocator,

    pub fn from_bytes(bytes: []u8, allocator: std.mem.Allocator) !Function {
        var ip: usize = @sizeOf(usize);
        const name_sz = std.mem.readIntSliceLittle(usize, bytes[0..@sizeOf(usize)]);
        var name = bytes[ip .. ip + name_sz];
        ip += name_sz;
        std.log.debug("fn {s}", .{name});

        const args_sz = std.mem.readIntSliceLittle(usize, bytes[ip .. ip + @sizeOf(usize)]);
        ip += @sizeOf(usize);
        var args: []VMType = try allocator.alloc(VMType, args_sz);
        var processed_args: usize = 0;
        while (processed_args < args_sz) {
            args[processed_args] = try VMType.from_byte(bytes[ip]);
            std.log.debug("- arg: {s}", .{@tagName(args[processed_args])});
            ip += 1;
            processed_args += 1;
        }

        const rets_sz = std.mem.readIntSliceLittle(usize, bytes[ip .. ip + @sizeOf(usize)]);
        ip += @sizeOf(usize);

        var rets: []VMType = try allocator.alloc(VMType, rets_sz);
        var processed_rets: usize = 0;
        while (processed_rets < rets_sz) {
            rets[processed_rets] = try VMType.from_byte(bytes[ip]);
            std.log.debug("- ret: {s}", .{@tagName(rets[processed_rets])});
            ip += 1;
            processed_rets += 1;
        }

        const code_sz = std.mem.readIntSliceLittle(usize, bytes[ip .. ip + @sizeOf(usize)]);
        ip += @sizeOf(usize);
        var code: []u8 = try allocator.alloc(u8, code_sz);
        std.mem.copy(u8, code, bytes[ip .. ip + code_sz]);
        std.log.debug("- code: {d} bytes", .{code.len});

        return Function{ .name = name, .args = args, .rets = rets, .code = code, ._allocator = allocator };
    }

    pub fn deinit(self: *const Function) void {
        self._allocator.free(self.rets);
        self._allocator.free(self.args);
        self._allocator.free(self.code);
        _ = self;
    }
};

const Binary = struct {
    // magic: [4]u8, // = "cbvm"
    // version: u8, // = 0
    // function_c: usize
    functions: []Function,

    _allocator: std.mem.Allocator,

    pub fn from_bytes(bytes: []u8, allocator: std.mem.Allocator) !Binary {
        const min_sz = 5 + @sizeOf(usize);
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

        const function_c = std.mem.readIntSliceLittle(usize, bytes[5 .. 5 + @sizeOf(usize)]);
        std.log.debug("{d} functions in binary", .{function_c});
        var ip: usize = 5 + @sizeOf(usize);

        var functions = try allocator.alloc(Function, function_c);
        var processed_funcs: usize = 0;
        while (processed_funcs < function_c) {
            const fn_sz = std.mem.readIntSliceLittle(usize, bytes[ip .. ip + @sizeOf(usize)]);
            ip += @sizeOf(usize);
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

fn read_file(path: []u8, allocator: std.mem.Allocator) ![]u8 {
    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const realpath = try std.fs.realpath(path, &path_buffer);

    const file = try std.fs.openFileAbsolute(realpath, .{ .read = true });
    defer file.close();

    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
        // .verbose_log = true,
    }){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var argv = std.process.args();
    defer argv.deinit();

    const program = try argv.next(allocator).?;
    defer allocator.free(program);

    const file_path = try argv.next(allocator) orelse {
        std.log.err("expected input file argument.", .{});
        std.log.info("usage: {s} <file>", .{program});
        return;
    };
    defer allocator.free(file_path);

    const file = try read_file(file_path, allocator);
    defer allocator.free(file);

    var bin = try Binary.from_bytes(file, allocator);
    defer bin.deinit();
}
