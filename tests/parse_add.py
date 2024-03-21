from common import *

def main():
    builder = BinaryBuilder()
    builder.add_function().set_name("add").add_arg(INT).add_arg(INT).add_ret(INT).add_code(bytes([0,0,0,0]))
    try:
        with open("parse_add.cbc", "wb") as f:
            f.write(builder.to_bytes())
        proc = subprocess.run([executable(), "parse_add.cbc", "--test"], capture_output=True)
        stderr = proc.stderr.decode().strip()  # for some reason, the binary outputs to stderr?

        output = '\n'.join([
            "debug: func add",
            "debug: < 1",
            "debug: < 1",
            "debug: > 1",
            "debug: = 4"
        ])

        assert proc.returncode == 0, stderr
        assert stderr == output, f"'{stderr}' != '{output}'"
    finally:
        os.remove("parse_add.cbc")