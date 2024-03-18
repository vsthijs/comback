#!/usr/bin/env python3

import sys
import os
import importlib
from contextlib import redirect_stdout, redirect_stderr
import io

toolsdir = os.path.dirname(__file__)
projdir = os.path.dirname(toolsdir)
testsdir = os.path.join(projdir, "tests")

sys.path.append(testsdir)  # make the tests "importable"
os.chdir(projdir)  # always expect to be in the home directory of the project


def list_tests() -> list[str]:
    def _F(el: str) -> bool:
        if el.endswith(".py") and el != "common.py":
            return True
        return False

    return list(filter(_F, os.listdir(testsdir)))


class Test:
    name: str
    path: str

    def __init__(self, name: str):
        if name + ".py" not in list_tests():
            raise RuntimeError(
                f"test '{name}' does not exist in the 'tests' directory."
            )
        self.name = name
        self.path = os.path.join(testsdir, name + ".py")

    def module(self):
        return importlib.import_module(self.name)

    def run(self) -> bool:
        try:
            mod = self.module()
            mod.main()
        except Exception as e:
            return e


def run_multiple(tests: list[Test]):
    total = len(tests)
    failed = []
    for index, test in enumerate(tests):
        print(f"test ({index+1}/{total}) {test.name}...", end=" ")
        stdout = io.StringIO()
        with redirect_stdout(stdout):
            result = test.run()
        if result:
            print("Failed")
            print(stdout.getvalue().removesuffix("\n"))
            print(result)
            failed.append(test)
        else:
            print("Ok")
    print(
        f"{total} tests ran, of which {len(failed)} failed",
        end=(":\n" if len(failed) > 0 else "\n"),
    )
    (print(f"- {i.name}") for i in failed)


def run_all():
    return run_multiple([Test(t.removesuffix(".py")) for t in list_tests()])


if __name__ == "__main__":
    if len(sys.argv) >= 2:
        try:
            run_multiple([Test(t) for t in sys.argv[1:]])
        except RuntimeError as e:
            print("err:", e)
    else:
        run_all()
    # print(list_tests())
