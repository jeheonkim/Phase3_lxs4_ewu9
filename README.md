# Project Phase 3 - mC Semantic Analyzer

The parser builds an AST and checks declarations, function calls, array indexing,
and assignment types as input is parsed. Identifiers use global and function-local
scopes; locals may shadow globals. Function entries record the return type and
ordered parameter types, including array parameters.

## Build and test

On a Linux server with gcc, make, flex, bison, libfl, and Python 3, run
`make clean && make`, followed by `make test`. Run a single input with
`./obj/mcc input.mC`; add `--ast` or `--sym` to print the AST or symbol table.
`python3 test/run_tests.py -v` shows output differences.

Complete the personal and contribution fields in `writeup.txt` before submission.
See the project PDF for the official requirements and submission policy.
