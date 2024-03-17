# comback

A virtual machine written in Zig.

## binary layout

The files are expected to have the following encoding. Everything is encoded in little-endian.

```C
struct BytecodeFile {
    uint8_t magic[4]; // "cbvm"
    uint8_t version; // 0
    size_t functions_sz; // amount of functions
    struct Function functions[functions_sz];
};
```

```C
struct Function {
    size_t name_sz;
    char name[name_sz];
    size_t args_sz; // amount of arguments
    uint8_t args[args_sz]; // argument types
    size_t rets_sz; // amount of return values
    uint8_t rets[rets_sz]; // return types
    size_t code_sz; // length of the code
    uint8_t code[code_sz];
};
```

### Types

Types are encoded as a single byte. There are currently 3 types: `uint`(0), `int`(1) and `bool`(2).
