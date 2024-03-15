const std = @import("std");

const VMError = error{
    StackUnderflow,
    DecodeError,
    UnknownRegister,
    CodeOverflow,
};

const VMType = enum { int, uint, bool };

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
    heap: std.mem.Allocator,
    stack: std.ArrayList(VMValue),
    code: []u8,
    registers: [32]VMValue,

    _ip: usize,

    pub fn new(code: []u8) VMContext {
        var heap = std.heap.ArenaAllocator.init(std.heap.page_allocator).allocator();
        var stack = std.ArrayList(VMValue).init(heap);
        return VMContext{ .heap = heap, .stack = stack, .code = code, .registers = undefined, ._ip = 0 };
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

test "VMContext.push" {
    var buf = [0]u8{};
    var vm = VMContext.new(&buf);
    try vm.push(VMValue.from_usize(69));
    var val = try vm.pop();
    try std.testing.expect(val.value.uint == 69);
}
