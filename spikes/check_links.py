#!/usr/bin/env python3
"""Check that every URL in management_links.json still resolves.

Usage:
    python3 spikes/check_links.py

Reports each URL as ok, blocked (the site refused a script, so it can't be
checked this way — open it by hand) or BROKEN (404/410/5xx/unreachable).
Exits 1 if anything is broken. Can't tell whether a signed-in user lands on the
right screen; that still needs a manual check.
"""

import json
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

LINKS = Path(__file__).resolve().parent / "rotation" / "management_links.json"
FIELDS = ("manage", "cancel", "web", "android", "source")
HEADERS = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15"}


def urls():
    data = json.loads(LINKS.read_text())
    found = {}
    for group in ("services", "billers"):
        for name, entry in data[group].items():
            for field in FIELDS:
                url = entry.get(field)
                if url and url.startswith("http"):
                    found.setdefault(url, []).append(f"{name}.{field}")
    for ex in data["exceptions"]:
        found.setdefault(ex["source"], []).append("exception.source")
    return found


def check(url):
    for method in ("HEAD", "GET"):  # some sites mishandle HEAD, so confirm with GET
        try:
            req = urllib.request.Request(url, method=method, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=15) as resp:
                return "ok", resp.status
        except urllib.error.HTTPError as e:
            if method == "HEAD":
                continue
            if e.code in (401, 403, 429, 503):  # 503: also how Amazon turns away scripts
                return "blocked", e.code
            return "BROKEN", e.code
        except Exception as e:  # DNS, TLS, timeout
            if method == "HEAD":
                continue
            return "BROKEN", type(e).__name__
    return "BROKEN", "no response"


def main():
    found = urls()
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = dict(zip(found, pool.map(check, found)))

    order = {"BROKEN": 0, "blocked": 1, "ok": 2}
    for url, (status, code) in sorted(results.items(), key=lambda r: order[r[1][0]]):
        print(f"{status:<8} {str(code):<5} {url}")
        if status != "ok":
            print(f"               used by: {', '.join(found[url])}")

    counts = {s: sum(1 for r in results.values() if r[0] == s) for s in order}
    print(f"\n{counts['ok']} ok, {counts['blocked']} blocked (check by hand), {counts['BROKEN']} broken")
    sys.exit(1 if counts["BROKEN"] else 0)


if __name__ == "__main__":
    main()
