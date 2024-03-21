## clean.sh

clean the working tree.

## verify.sh

run all tests after cleaning the working tree.

## test.py

run the test suite.

## cbas.py

the debug assembler.

The following functions accepts two `INT` arguments, and returns one `INT`. it adds the two numbers and returns the result.

```
func add
< int
< int
> int
    add
    ret
```

it is the same as

```C
int add(int a, int b) {
    return a + b;
}
```