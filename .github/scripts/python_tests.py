#!/usr/bin/env python3
"""Run the Python spike tests and write a Markdown summary.

Usage:
    python_tests.py SUMMARY_FILE

Prints the usual unittest output, appends a results table to SUMMARY_FILE
(GitHub's $GITHUB_STEP_SUMMARY), and exits non-zero if anything failed.
"""

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main(summary_path):
    suite = unittest.defaultTestLoader.discover(str(ROOT / "spikes" / "rotation"))
    result = unittest.TextTestRunner(verbosity=2).run(suite)

    failed = [str(test) for test, _ in result.failures + result.errors]
    passed = result.testsRun - len(failed) - len(result.skipped)
    status = "✅ All passed" if not failed else f"❌ {len(failed)} failed"
    lines = [
        f"## Python prototype: {status}",
        "",
        "| Passed | Failed | Skipped |",
        "| ---: | ---: | ---: |",
        f"| {passed} | {len(failed)} | {len(result.skipped)} |",
    ]
    if failed:
        lines += ["", "### Failed tests"] + [f"- `{name}`" for name in failed]
    with open(summary_path, "a") as f:
        f.write("\n".join(lines) + "\n")
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
