## Writing tests

1. Create a python script in this directory.
2. optionally `import common`.
3. write a `main()` function.

A succesfull test should never raise an exception. Asserts are recommended.

## Testing everything

Run the following command in the home directory of the repo.

```sh
$ ./tools/test.py

# specific tests can also be run by passing the names.
$ ./tools/test.py tools  # runs the tools.py test.
```
