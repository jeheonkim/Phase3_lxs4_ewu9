#!/usr/bin/env python3
"""Run the sample test cases against your semantic analyzer.

    make test

or directly:

    python3 test/run_tests.py            # build first with `make`
    python3 test/run_tests.py -v         # show the full diff for each failure

For every file in test/cases/*.mC it runs obj/mcc on it with no flags and
compares the output with test/exp/<name>.exp.

This comparison IS exact. Phase 3's expected output is a list of error lines
followed by "Compilation finished.", and the wording and the line numbers both
count, so copy the message text from the .exp files exactly, including the two
messages that have no full stop at the end.

Passing every case here is necessary, not sufficient: grading also runs cases
you have not seen. Write your own tests too, which is what section 3 of the
writeup asks you to describe.
"""
import argparse
import difflib
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

CASES = os.path.join(HERE, 'cases')
EXPS = os.path.join(HERE, 'exp')
TIMEOUT = 10


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-v', '--verbose', action='store_true',
                    help='show the full diff for each failing case')
    ap.add_argument('--program', default=os.path.join(ROOT, 'obj', 'mcc'))
    a = ap.parse_args()

    if not os.access(a.program, os.X_OK):
        print(f'{a.program} not found or not executable. Run `make` first.')
        return 2

    if not os.path.isdir(CASES):
        print(f'no test cases in {CASES}')
        return 2

    names = sorted(f[:-3] for f in os.listdir(CASES) if f.endswith('.mC'))
    passed = failed = 0

    for name in names:
        case = os.path.join(CASES, name + '.mC')
        expf = os.path.join(EXPS, name + '.exp')
        if not os.path.isfile(expf):
            print(f'  [SKIP] {name:<20} no expected output')
            continue

        try:
            p = subprocess.run([a.program, case], capture_output=True,
                               timeout=TIMEOUT)
        except subprocess.TimeoutExpired:
            print(f'  [FAIL] {name:<20} did not terminate within {TIMEOUT}s')
            failed += 1
            continue

        got = (p.stdout + p.stderr).decode('utf-8', 'replace')
        with open(expf, encoding='utf-8') as fh:
            want = fh.read()

        if got.strip() == want.strip():
            print(f'  [PASS] {name}')
            passed += 1
            continue

        failed += 1
        print(f'  [FAIL] {name}')
        if a.verbose:
            for ln in difflib.unified_diff(want.splitlines(), got.splitlines(),
                                           'expected', 'yours', lineterm=''):
                print('         ' + ln)
        else:
            w = [l for l in want.splitlines() if l.strip()]
            g = [l for l in got.splitlines() if l.strip()]
            for ln in w:
                if ln not in g:
                    print(f'         missing: {ln}')
            for ln in g:
                if ln not in w:
                    print(f'         unexpected: {ln}')

    print()
    print(f'  {passed} passed, {failed} failed')
    if failed and not a.verbose:
        print('  run with -v to see the full diff')
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
