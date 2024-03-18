"""
Tests the common tools.
"""

from common import *


def generate_add() -> bytes:
    builder = BinaryBuilder()
    builder.add_function().set_name("add").add_arg(INT).add_arg(INT).add_ret(INT)
    return builder.to_bytes()


def verify_add(bc: bytes):
    binary = parse_binary(bc)
    assert len(binary.functions), "more than one functions found"
    func = binary.functions[0]
    assert func.name == "add", f"function has unexpected name: '{func.name}'"
    assert func.args == [
        INT,
        INT,
    ], f"function arguments are wrong: ({', '.join(i2t(i) for i in func.args)})"
    assert func.rets == [
        INT
    ], f"function returns are wrong: ({', '.join(i2t(i) for i in func.rets)})"


def verify_add_wrong(bc: bytes):
    binary = parse_binary(bc)
    assert len(binary.functions), "more than one functions found"
    func = binary.functions[0]
    assert func.name == "add", f"function has unexpected name: '{func.name}'"
    assert func.args == [
        INT,
        INT,
    ], f"function arguments are wrong: ({', '.join(i2t(i) for i in func.args)})"
    assert func.rets == [
        INT,
        INT,
    ], f"function returns are wrong: ({', '.join(i2t(i) for i in func.rets)})"


def main():
    add_binary = generate_add()
    verify_add(add_binary)
    expect(verify_add_wrong, AssertionError, add_binary)
