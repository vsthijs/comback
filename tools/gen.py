#!/usr/bin/env python3

"""
Simple script to generate .cbc files easily.
See generate() to create a custom binary.
"""

# flags
DEST_FILE = "test.cbc"

# constants
UINT = 0
INT = 1
BOOL = 2


class FunctionBuilder:
    def __init__(self):
        self.args = []
        self.rets = []
        self.code = bytes()

    def set_name(self, name: str):
        self.name = name
        return self

    def add_arg(self, type: int):
        self.args.append(type)
        return self

    def add_ret(self, type: int):
        self.rets.append(type)
        return self

    def add_code(self, code: bytes):
        self.code += code
        return self

    def to_bytes(self) -> bytes:
        # name
        data = len(self.name).to_bytes(8, "little")
        data += self.name.encode("utf-8")

        # args
        data += len(self.args).to_bytes(8, "little")
        for ii in self.args:
            data += int(ii).to_bytes(1, "little")

        # rets
        data += len(self.rets).to_bytes(8, "little")
        for ii in self.rets:
            data += int(ii).to_bytes(1, "little")

        data += len(self.code).to_bytes(8, "little")
        data += self.code

        return len(data).to_bytes(8, "little") + data


class BytecodeBuilder:
    def __init__(self):
        self.functions = []

    def add_function(self):
        fn = FunctionBuilder()
        self.functions.append(fn)
        return fn

    def to_bytes(self):
        data = "cbvm".encode("utf-8")
        data += (0).to_bytes(1, "little")
        data += len(self.functions).to_bytes(8, "little")
        for ii in self.functions:
            data += ii.to_bytes()
        return data


def generate(builder: BytecodeBuilder):
    # use bytecodebuilder here to generate the bytecode

    (
        builder.add_function()
        .set_name("add")
        .add_arg(INT)
        .add_arg(INT)
        .add_ret(INT)
        .add_code(bytes([0, 0, 0, 0]))
    )


if __name__ == "__main__":
    builder = BytecodeBuilder()
    generate(builder)
    with open(DEST_FILE, "wb") as f:
        f.write(builder.to_bytes())
