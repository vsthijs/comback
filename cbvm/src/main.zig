const std = @import("std");

const VMType = enum { int, uint, bool };

const VMValue = struct {
    type: VMType,
    value: union { int: isize, uint: usize, bool: bool },
};

const VMContext = struct {
    heap: std.heap.HeapAllocator,
    stack: std.ArrayList(VMValue),
    code: []u8,

    pub fn new(heap_sz: usize, code: []u8) VMContext {
        var heap = std.heap.ArenaAllocator.init(std.heap.FixedBufferAllocator.init([heap_sz]u8{0})).allocator();
        var stack = std.ArrayList(VMValue).init(heap);
        return VMContext{ .heap = heap, .stack = stack, .code = code };
    }

    pub fn push(self: *VMContext, value: VMValue) !void {
        self.stack.append(value);
    }
};

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
