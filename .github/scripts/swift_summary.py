#!/usr/bin/env python3
"""Turn Swift test results and coverage into a readable Markdown summary.

Usage:
    swift_summary.py RESULTS.xml COVERAGE.json

RESULTS.xml is `swift test --xunit-output` (Swift Testing writes it as
results-swift-testing.xml); COVERAGE.json is `llvm-cov export -summary-only`.
Prints Markdown for GitHub's job summary. Coverage is reported, not enforced.
"""

import json
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict

# What each test target covers, in plain words.
TARGETS = {
    "RotationEngineTests": "Planning engine",
    "PersistenceTests": "Saving on the phone",
    "TMDBTests": "TMDB search",
}
SOURCES = {
    "RotationEngine": "Planning engine",
    "Persistence": "Saving on the phone",
    "TMDB": "TMDB search",
}


def tests(path):
    """{target: (passed, failed, skipped)} and a list of failed test names."""
    counts = defaultdict(lambda: [0, 0, 0])
    failures = []
    for case in ET.parse(path).getroot().iter("testcase"):
        cls = case.get("classname", "")
        target = cls.split(".")[0]
        if case.find("failure") is not None or case.find("error") is not None:
            counts[target][1] += 1
            failures.append(f"{cls}.{case.get('name')}")
        elif case.find("skipped") is not None:
            counts[target][2] += 1
        else:
            counts[target][0] += 1
    return counts, failures


def coverage(path):
    """{source target: (covered lines, total lines)} and per-file rows."""
    totals = defaultdict(lambda: [0, 0])
    files = []
    for f in json.load(open(path))["data"][0]["files"]:
        name = f["filename"].split("/Sources/")[-1]
        lines = f["summary"]["lines"]
        target = name.split("/")[0]
        totals[target][0] += lines["covered"]
        totals[target][1] += lines["count"]
        files.append((name, lines["covered"], lines["count"]))
    return totals, files


def pct(covered, count):
    return f"{100 * covered / count:.1f}%" if count else "–"


def main(results_path, coverage_path):
    counts, failures = tests(results_path)
    totals, files = coverage(coverage_path)
    passed = sum(c[0] for c in counts.values())
    failed = sum(c[1] for c in counts.values())

    out = []
    status = "✅ All passed" if failed == 0 else f"❌ {failed} failed"
    out.append(f"## Swift package: {status}")
    out.append("")
    out.append("| Area | Passed | Failed | Skipped |")
    out.append("| --- | ---: | ---: | ---: |")
    for target in sorted(counts, key=lambda t: list(TARGETS).index(t) if t in TARGETS else 99):
        p, f, s = counts[target]
        out.append(f"| {TARGETS.get(target, target)} | {p} | {f} | {s} |")
    out.append(f"| **Total** | **{passed}** | **{failed}** | **{sum(c[2] for c in counts.values())}** |")

    if failures:
        out.append("")
        out.append("### Failed tests")
        out.extend(f"- `{name}`" for name in failures)

    all_covered = sum(c[0] for c in totals.values())
    all_count = sum(c[1] for c in totals.values())
    out.append("")
    out.append(f"## Code coverage: {pct(all_covered, all_count)} of lines")
    out.append("")
    out.append("| Area | Lines covered | Coverage |")
    out.append("| --- | ---: | ---: |")
    for target in sorted(totals, key=lambda t: list(SOURCES).index(t) if t in SOURCES else 99):
        c, n = totals[target]
        out.append(f"| {SOURCES.get(target, target)} | {c} / {n} | {pct(c, n)} |")

    out.append("")
    out.append("<details><summary>Coverage by file</summary>")
    out.append("")
    out.append("| File | Lines covered | Coverage |")
    out.append("| --- | ---: | ---: |")
    for name, c, n in sorted(files, key=lambda f: f[1] / f[2] if f[2] else 1):
        out.append(f"| `{name}` | {c} / {n} | {pct(c, n)} |")
    out.append("")
    out.append("</details>")
    print("\n".join(out))


if __name__ == "__main__":
    main(*sys.argv[1:3])
