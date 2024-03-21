#!/usr/bin/env python3

import os
import sys

projdir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
testsdir = os.path.join(projdir, "tests")
sys.path.append(testsdir)


import common as cbc


def parse_asm(inp: str) -> bytes:
    builder = cbc.BinaryBuilder()
    fn: cbc.FunctionBuilder | None = None
    state = 0

    def inst_from_line(line: str) -> bytes:
        line: list[str] = line.split(" ")
        match line:
            case ["halt"]:
                return cbc.Inst.halt()
            case ["push", operand]:
                if operand in ["true", "false"]:
                    type = cbc.BOOL
                    value = 1 if operand == "true" else 0
                elif operand.endswith("i"):
                    type = cbc.INT
                    value = int(operand.removesuffix("i"))
                elif operand.endswith("u"):
                    type = cbc.UINT
                    value = int(operand.removesuffix("u"))
                else:
                    raise ValueError("invalid operand")
                return cbc.Inst.push(type, value)
            case ["add"]:
                return cbc.Inst.add()
            case ["sub"]:
                return cbc.Inst.sub()
            case ["mul"]:
                return cbc.Inst.mul()
            case ["div"]:
                return cbc.Inst.div()
            case ["dup", operand]:
                offset = int(operand)
                return cbc.Inst.dup(offset)
            case ["ret"]:
                return cbc.Inst.ret()

    for line in inp.splitlines():
        if line.startswith("func ") and line.endswith(":"):
            fn = builder.add_function()
            fn.set_name(line.removeprefix("func ").removesuffix(":"))
            state = 1
        elif state == 1:
            if line.startswith("< "):
                argtype = {"uint": 0, "int": 1, "bool": 2}[line.removeprefix("< ")]
                fn.add_arg(argtype)
            elif line.startswith("> "):
                state = 2
                argtype = {"uint": 0, "int": 1, "bool": 2}[line.removeprefix("> ")]
                fn.add_ret(argtype)
        elif state == 2:
            if line.startswith("> "):
                argtype = {"uint": 0, "int": 1, "bool": 2}[line.removeprefix("> ")]
                fn.add_ret(argtype)
            elif line.strip() != "":
                state = 3
                fn.add_code(inst_from_line(line.strip()))
        elif state == 3:
            if line.strip() != "":
                fn.add_code(inst_from_line(line.strip()))
        else:
            assert False, "Unreachable"

    builder.to_binary().pretty()
    return builder.to_bytes()


def shift(l: list) -> tuple:
    return l[0], l[1:]


def main(argv: list[str]) -> int:
    prog, argv = shift(argv)

    try:
        inp, argv = shift(argv)
    except IndexError:
        print(f"err: expected source file")
        return 1

    try:
        output, argv = shift(argv)
    except IndexError:
        output = os.path.splitext(inp)[0] + ".cbc"  # default output file

    with open(inp, "r") as f:
        binary = parse_asm(f.read())
    with open(output, "wb") as f:
        f.write(binary)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
