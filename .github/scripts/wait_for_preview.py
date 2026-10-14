#!/usr/bin/env python3
"""Wait for a pull request's Cloudflare preview to serve this commit's site.

Usage:
    wait_for_preview.py BRANCH SUBDOMAIN [--timeout SECONDS]

Cloudflare builds a preview for every pull request at
<branch>-flixshift.<subdomain>.workers.dev. This polls it until the files it
serves match site/public/ in the checkout, so the link we post is never for
an older push. Prints the URL on success; exits 1 if it never catches up.
"""

import argparse
import re
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SITE = ROOT / "site" / "public"
WORKER = "flixshift"
# Pages whose content proves the preview is this commit's.
CHECK = ["index.html", "styles.css", "privacy/index.html"]


def preview_url(branch, subdomain):
    # A DNS label is at most 63 characters, including "-flixshift".
    name = re.sub(r"[^a-z0-9]+", "-", branch.lower()).strip("-")
    name = name[: 63 - len(WORKER) - 1].strip("-")
    return f"https://{name}-{WORKER}.{subdomain}.workers.dev/"


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "flixshift-preview-check"})
    with urllib.request.urlopen(request, timeout=15) as response:
        return response.read()


def matches(base):
    for path in CHECK:
        try:
            if fetch(base + path.removesuffix("index.html")) != (SITE / path).read_bytes():
                return False, f"{path} is still the old version"
        except Exception as error:  # Not up yet, or a network hiccup.
            return False, f"{path}: {error}"
    return True, "up to date"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("branch")
    parser.add_argument("subdomain")
    parser.add_argument("--timeout", type=int, default=420)
    args = parser.parse_args()

    url = preview_url(args.branch, args.subdomain)
    deadline = time.monotonic() + args.timeout
    while True:
        ok, status = matches(url)
        print(f"{url}: {status}", file=sys.stderr)
        if ok:
            print(url)
            return 0
        if time.monotonic() > deadline:
            print(f"Gave up after {args.timeout}s waiting for {url}", file=sys.stderr)
            return 1
        time.sleep(15)


if __name__ == "__main__":
    sys.exit(main())
