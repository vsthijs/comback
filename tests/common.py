"""
Contains common used tools for testing and manipulation of binaries
"""

from dataclasses import dataclass
import sys
import typing
import os
import subprocess


testsdir = os.path.abspath(os.path.dirname(__file__))
projdir = os.path.dirname(testsdir)
cbvmdir = os.path.join(projdir, "cbvm")


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
            + "{\n"
            + "      "
            + str((self.code))
            + "\n    }"
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
        self.functions: list[FunctionBuilder] = []

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

    def to_binary(self) -> Binary:
        return Binary(
            b"cbvm",
            0,
            [Function(f.name, f.args, f.rets, f.code) for f in self.functions],
        )


class ExpectError(Exception):
    pass


def expect(fn: typing.Callable, e: type[Exception], *args, **kwargs):
    try:
        fn(*args, **kwargs)
        raise ExpectError(
            f"{fn.__name__} didn't raise the expected exception '{e.__name__}'"
        )
    except e as ex:
        print(f"expected {e}")
        return


def executable() -> str:
    """Returns the path of the cbvm executable, and builds it if it does not exist."""

    if sys.platform == "linux":
        exepath = os.path.join(cbvmdir, "zig-out", "bin", "cbvm")  # on linux
    elif sys.platform == "win32":
        exepath = os.path.join(cbvmdir, "zig-out", "bin", "cbvm.exe")  # on windows
    else:
        raise RuntimeError("unrecognized platform.")

    if not os.path.exists(exepath) or True:
        old = os.getcwd()
        try:
            os.chdir(cbvmdir)
            if (
                ret := subprocess.call(["zig", "build"], stdout=subprocess.DEVNULL)
            ) != 0:
                raise RuntimeError(f"the build of cbvm failed with exit code {ret}")
        finally:
            os.chdir(old)

    return exepath


def u8(i: int) -> bytes:
    return (i).to_bytes(1, "little")


def u16(i: int) -> bytes:
    return (i).to_bytes(2, "little")


def u64(i: int, signed=False) -> bytes:
    return (i).to_bytes(8, "little", signed=signed)


def v2b(type: typing.Literal[UINT, INT, BOOL], value: int) -> bytes:
    if type == UINT:
        return u64(value)
    elif type == INT:
        return u64(value, True)
    elif type == BOOL:
        return u8(value)
    else:
        raise TypeError("expected UINT, INT or BOOL")


class Inst:
    def opcode(name: str):
        return {
            # basic
            "halt": 0,
            "push": 1,  # <type> (value)
            "add": 2,
            "sub": 3,
            "mul": 4,
            "div": 5,
            "dup": 6,  # (offset)
            "ret": 7,
            # misc.
        }[name]

    @staticmethod
    def halt() -> bytes:
        return u8(Inst.opcode("halt"))

    @staticmethod
    def push(type: typing.Literal[UINT, INT, BOOL], value: int) -> bytes:
        return u8(Inst.opcode("push")) + u8(type) + v2b(type, value)

    @staticmethod
    def add() -> bytes:
        return u8(Inst.opcode("add"))

    @staticmethod
    def sub() -> bytes:
        return u8(Inst.opcode("sub"))

    @staticmethod
    def mul() -> bytes:
        return u8(Inst.opcode("mul"))

    @staticmethod
    def div() -> bytes:
        return u8(Inst.opcode("div"))

    @staticmethod
    def dup(offset: int) -> bytes:
        return u8(Inst.opcode("dup")) + u8(offset)

    def ret() -> bytes:
        return u8(Inst.opcode("ret"))
