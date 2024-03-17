#!/usr/bin/env python3

"""
Simple script to read and verify a binary.
"""

from dataclasses import dataclass


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
            f"{name}({', '.join([i2t(i) for i in self.args])}) -> ({', '.join([i2t(i) for i in self.rets])}) "
            + "{"
            + str(len(code))
            + " bytes}"
        )


def parse_function(data: bytes) -> Function:
    # TODO: write function
    pass


@dataclass
class Binary:
    magic: bytes
    version: int
    functions: list[Function]


def parse_binary(data: bytes) -> Binary:
    # TODO: write function
    pass
