# Project Phase 3 — mC Semantic Analyzer

**CS 4318 — Compiler Construction**

## Overview

Build a static semantic analyzer for the **mC** language that augments the symbol table and AST (from Phase 2) with semantic information. The analyzer detects:

1. **Scoping errors** — undeclared and multiply declared identifiers
2. **Type errors** — type mismatches in assignments and function calls
3. **Array errors** — invalid indexing (non-array variables, non-integer or out-of-bounds indices)
4. **Function errors** — argument count and type mismatches

## Repository Structure

```
├── src/
│   ├── scanner.l      # Lexer, provided. Use it as is.
│   ├── parser.y       # EMPTY. Copy your Phase 2 parser here, then add the checks.
│   ├── tree.c / .h    # AST node definitions and printAst(), provided
│   ├── strtab.c / .h  # EMPTY .c. Copy your Phase 2 symbol table here, then extend it.
│   └── driver.c       # Entry point, provided, do not modify
├── test/
│   ├── cases/         # Sample .mC input programs
│   └── exp/           # Expected output for each test case
└── Makefile
```

## What you bring forward from Phase 2

`src/parser.y` and `src/strtab.c` ship empty **on purpose**. Phase 3 is built on
your own Phase 2 work, so you start by copying your Phase 2 versions of those two
files into `src/`. Everything else in `src/` is provided and current.

Five things to check as soon as you have copied them in, because the Phase 3
scaffolding is not identical to Phase 2's:

1. **Declare two more tokens.** The provided `scanner.l` returns `ERROR` and
   `ILLEGAL_TOK` for lexical errors. Your Phase 2 grammar does not declare them, so
   add this line to the token section of `parser.y`:

   ```
   %token ERROR ILLEGAL_TOK
   ```

   Without it the build stops with `'ERROR' undeclared`.

2. **Use the provided `scanner.l`.** Do not substitute your Phase 1 scanner. The
   provided one tracks line numbers the way the expected output below needs, and
   it is the scanner the token list above refers to.

3. **The symbol table API changed.** `src/strtab.h` is the Phase 3 version.
   `ST_insert` keeps its Phase 2 arguments in the same order, so those calls
   compile as they are. What is different:

   - `ST_insert` returns `-1` when the name is already declared in the
     **current** scope. That return value is how you detect a multiply
     declared symbol.
   - `ST_lookup` now takes only the name, searches the current scope and then
     its parents, and returns a pointer to the entry, or `NULL`, instead of an
     index. `ST_index(entry)` gives you the index when you need one.
   - New: `new_scope`, `up_scope`, `add_param`, `connect_params`,
     `get_symbol_id` and `print_sym_tab`.

   Your Phase 2 `strtab.c` will not satisfy this header until you extend it.
   The function table further down is the specification.

4. **Write `print_sym_tab()` and `get_symbol_id()`.** `driver.c` calls
   `print_sym_tab()` for the `--sym` flag, and `printAst` in `tree.c` calls
   `get_symbol_id(index)` to label an identifier node. You may not modify
   `driver.c`, so your `strtab.c` has to define both. The program will not link
   until they exist.

5. **Bring over anything you added to `tree.c` or `tree.h` in Phase 2.** If
   your Phase 2 `parser.y` calls a helper you wrote yourself, such as a
   `maketreeWithStr` or a `prependChild`, or uses a field you added to the node,
   copy that into the Phase 3 `tree.c` and `tree.h` too. Keep what Phase 3
   adds: the `scope`, `type` and `sym_type` fields, `flattenList`, and the
   provided `printAst`.

## An identifier node carries an index, not a name

`tree.h` gives a node an `int val` and no string field. For an identifier node,
`val` holds the **symbol table slot index**, which is why `ST_insert` returns an
`int` and `connect_params` takes an index. Look the entry up through the symbol
table rather than looking for a name on the node.

## Error message format

Your output is compared against `test/exp/`, so the wording has to match exactly.
Every message is one line of the form

```
error: line <N>: <message>
```

The eleven messages the sample tests expect, verbatim (note that two of them have
no trailing period):

```
Argument type mismatch in function call.
Array indexed using non-integer expression.
Array variable declared with size of zero.
Non-array identifier used as an array.
Statically sized array indexed with constant, out-of-bounds expression.
Symbol declared multiple times.
Too few arguments provided in function call.
Too many arguments provided in function call.
Type mismatch in assignment.
Undeclared variable
Undefined function
```

Errors are reported in source order, and the run still ends with
`Compilation finished.` as in Phase 2.

## Building

```sh
make clean && make
```

The binary is written to `obj/mcc`.

## Running

The compiler takes a source file as its argument, with optional flags to print the AST or symbol table:

```sh
./obj/mcc [--ast] [--sym] input.mC
./obj/mcc --help
```

| Flag | Effect |
|------|--------|
| `--ast` | Print a textual representation of the AST |
| `--sym` | Print a textual representation of the symbol table |
| `-h`, `--help` | Print usage information and exit |

## Testing

```sh
make test
```

Runs all cases in `test/cases/` against the expected output in `test/exp/`.

## What to Implement

### `strtab.c` — Hierarchical Symbol Table

The symbol table is a **tree of hash tables** mirroring the scope nesting. Each `table_node` holds a hash table of up to `MAXIDS` entries and pointers to its parent and child scopes.

| Function | Description |
|----------|-------------|
| `ST_insert(id, scope, data_type, symbol_type)` | Insert a symbol into the current scope's table; hash key = djb2(`scope` + `id`) % `MAXIDS`. Return its index, or `-1` if `id` is already declared in the current scope |
| `ST_lookup(id)` | Search from `current_scope` upward through parent scopes; return the entry or `NULL` |
| `new_scope()` | Create a child `table_node` and set it as `current_scope` |
| `up_scope()` | Move `current_scope` back to its parent |
| `add_param(data_type, symbol_type)` | Append a parameter to the `working_list` linked list |
| `connect_params(index, num_params)` | Attach the completed parameter list to the function's symbol entry. Call it right after the parameter list, before the body, so a recursive call inside the body sees the signature |
| `ST_index(entry)` | The index `ST_insert` returned for an entry `ST_lookup` found, or `-1` |
| `get_symbol_id(index)` | The identifier text for an index; `printAst` calls it |
| `print_sym_tab()` | Print the whole scope tree; `driver.c` calls it for `--sym` |

Symbol table entry fields:

| Field | Description |
|-------|-------------|
| `id` | Identifier name |
| `scope` | Enclosing function name, or empty string for globals |
| `data_type` | `INT_TYPE`, `CHAR_TYPE`, or `VOID_TYPE` |
| `symbol_type` | `SCALAR`, `ARRAY`, or `FUNCTION` |
| `size` | Number of elements (arrays) or number of parameters (functions) |
| `params` | Linked list of parameter types (functions only) |

### `parser.y` — Semantic Checks

Add the following checks to the grammar actions:

1. **Undeclared identifiers** — call `ST_lookup` on every variable/function use; emit an error if not found
2. **Multiply declared identifiers**: `ST_insert` returns `-1` when the name is already declared in the current scope. Do not test with `ST_lookup` first: it also searches the enclosing scopes, so a local that legally shadows a global would be reported
3. **Function call mismatch** — verify argument count and types match the function's signature
4. **Array indexing** — verify the variable is an array and the index is an integer within bounds
5. **Type mismatch in assignments** — verify left-hand and right-hand sides share the same type (for simple RHS expressions: variable, literal, or function call)

## Semantic Errors

| Error | Description |
|-------|-------------|
| Undeclared identifier | Variable or function used before declaration |
| Multiply declared identifier | Same name declared more than once in the same scope |
| Function call mismatch | Wrong number of arguments or wrong argument type |
| Array indexing error | Non-array variable indexed, or index is non-integer / out-of-bounds |
| Type mismatch | Left- and right-hand sides of an assignment have different types |

## Extra Credit: AST Minimization

As an optional extra credit extension, you may minimize the AST by removing or collapsing redundant nodes (e.g., pass-through productions with a single child). This is not a strict requirement and will not affect your base score.

## Grading Rubric

| Category | Points |
|----------|--------|
| Symbol Table (type, scope, function info) | 20 |
| Undeclared/Multiply Declared Variables | 10 |
| Undeclared/Multiply Declared Functions | 10 |
| Function Call Mismatch | 10 |
| Array Indexing | 10 |
| Type Mismatch | 10 |
| Compile & Run | 10 |
| Documentation | 10 |
| Writeup | 10 |
| **Total** | **100** |

## Writeup (`writeup.txt`)

Required sections:
1. Your name and course ID
2. Group members and their respective contributions
3. Two test examples (different from those provided) demonstrating correctness
4. Any extra build instructions if you deviate from the provided Makefile

## Submission

**See `Project_Phase_3.pdf` for the due date, the slip-day rule and the late
penalty table.** They are stated there and only there, so that this file never
goes stale.

In short: submit a zip archive to Canvas named
`ProjectPhase3_<netID1>_<netID2>.zip`, containing all source files with the original
directory structure intact. Only what is submitted on Canvas is graded. Pushing
to your repository is not submitting.
