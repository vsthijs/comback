"""
Contains common used tools for testing and manipulation of binaries
"""

from dataclasses import dataclass
import sys


def i2t(i: int) -> str:
    return {0: "uint", 1: "int", 2: "bool"}[i]


@dataclass
class Function:
    name: str
    args: list[int]
    rets: list[int]
    code: bytes

    def __str__(self) -> str:
        return (
            f"{self.name}({', '.join([i2t(i) for i in self.args])}) -> ({', '.join([i2t(i) for i in self.rets])}) "
            + "{"
            + str(len(self.code))
            + " bytes}"
        )


def parse_function(data: bytes) -> Function:
    name_len = int.from_bytes(data[:8], "little")
    ip = 8
    name = data[ip : ip + name_len]
    ip += name_len

    args_len = int.from_bytes(data[ip : ip + 8], "little")
    ip += 8
    args = []
    while len(args) < args_len:
        args.append(data[ip])
        ip += 1

    rets_len = int.from_bytes(data[ip : ip + 8], "little")
    ip += 8
    rets = []
    while len(rets) < rets_len:
        rets.append(data[ip])
        ip += 1

    code = data[ip:]
    return Function(name.decode("utf-8"), args, rets, code)


@dataclass
class Binary:
    magic: bytes
    version: int
    functions: list[Function]

    def pretty(self):
        print("Binary {")
        print(f"  magic   = {self.magic}")
        print(f"  version = {self.version}")
        print(f"  functions({len(self.functions)})" + " {")
        for ii in self.functions:
            print(f"    {str(ii)}")
        print("  }")
        print("}")


def parse_binary(data: bytes) -> Binary:
    # TODO: write function
    magic = data[:4]
    if magic.decode("utf-8") != "cbvm":
        print("warning: invalid magic code")

    version = data[4]
    if version != 0:
        print("warning: invalid format version")

    functions_len = int.from_bytes(data[5 : 5 + 8], "little")
    functions = []
    ip = 13
    while len(functions) < functions_len:
        fn_sz = int.from_bytes(data[ip : ip + 8], "little")
        ip += 8
        functions.append(parse_function(data[ip : ip + fn_sz]))
        ip += fn_sz

    return Binary(magic, version, functions)


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


class BinaryBuilder:
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
