#!/usr/bin/env python3

"""
Simple script to read and verify a binary.
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


if __name__ == "__main__":
    assert len(sys.argv) >= 2, f"{sys.argv[0]} <file.cbc>"

    path = sys.argv[1]
    with open(path, "rb") as f:
        file = f.read()

    binary = parse_binary(file)
    binary.pretty()
