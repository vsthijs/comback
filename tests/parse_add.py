from common import *

def main():
    builder = BinaryBuilder()
    builder.add_function().set_name("add").add_arg(INT).add_arg(INT).add_ret(INT).add_code(bytes([0,0,0,0]))
    try:
        with open("parse_add.cbc", "wb") as f:
            f.write(builder.to_bytes())
        proc = subprocess.Popen([executable(), "parse_add.cbc", "--test"], stdout=subprocess.PIPE)
        result = proc.wait()
        
        # TODO: silence output of cbvm
        # TODO: check output of cbvm
        assert result == 0, "vm failed"
    finally:
        os.remove("parse_add.cbc")