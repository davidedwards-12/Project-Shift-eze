#!/usr/bin/env python3
"""Spike: plan a monthly streaming rotation for a watchlist under a budget.

Usage:
    python3 spikes/rotation/rotate.py --budget 40 [--services FILE] [--watchlist FILE]

Model (v1):
  - Each title must be watched on one service that carries it, for `months`
    consecutive months (default 1).
  - Step 1 picks the cheapest set of services covering every title (exhaustive
    search; fine for ~15 services).
  - Step 2 packs those services into months without exceeding the budget,
    highest-priority titles (earliest in the watchlist) first.
  - Savings compare the plan with keeping `current` services for the same span.

Not modeled yet: renewal dates, annual plans, promos, bundles, titles that
leave a service, new titles arriving mid-plan.
"""

import argparse
import itertools
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def load(services_path, watchlist_path):
    services = json.loads(Path(services_path).read_text())["services"]
    lookup = {}
    for s in services:
        for n in [s["name"], *s["aliases"]]:
            lookup[n.lower()] = s["name"]

    titles = []
    for t in json.loads(Path(watchlist_path).read_text())["titles"]:
        # Normalize provider names; drop providers we don't track (e.g. cable VOD).
        on = sorted({lookup[p.lower()] for p in t["services"] if p.lower() in lookup})
        titles.append({"title": t["title"], "services": on, "months": t.get("months", 1)})
    return {s["name"]: s for s in services}, titles


def assign(titles, chosen, services):
    """Map each title to the cheapest chosen service that carries it."""
    out = {}
    for t in titles:
        options = [s for s in t["services"] if s in chosen]
        if not options:
            return None
        out[t["title"]] = min(options, key=lambda s: services[s]["price"])
    return out


def durations(titles, assignment):
    """Months each service must stay active: the longest title assigned to it."""
    need = {}
    for t in titles:
        s = assignment[t["title"]]
        need[s] = max(need.get(s, 0), t["months"])
    return need


def cheapest_cover(titles, services, budget):
    """Exhaustively find the lowest-cost service set that covers every title."""
    names = sorted({s for t in titles for s in t["services"]})
    best = None
    for r in range(1, len(names) + 1):
        for combo in itertools.combinations(names, r):
            if any(services[s]["price"] > budget for s in combo):
                continue
            a = assign(titles, set(combo), services)
            if a is None:
                continue
            need = durations(titles, a)
            cost = sum(services[s]["price"] * m for s, m in need.items())
            if best is None or cost < best[0]:
                best = (cost, a, need)
    return best


def schedule(titles, services, assignment, need, budget):
    """Greedy month-by-month packing, in watchlist priority order."""
    # Order services by the priority of the first title that needs them.
    order = []
    for t in titles:
        s = assignment[t["title"]]
        if s not in order:
            order.append(s)

    months = []  # each month: {service: price}
    for s in order:
        price = services[s]["price"]
        start = 0
        # Find the first run of need[s] consecutive months with room for s.
        while True:
            while len(months) < start + need[s]:
                months.append({})
            window = months[start:start + need[s]]
            if all(sum(m.values()) + price <= budget + 1e-9 for m in window):
                for m in window:
                    m[s] = price
                break
            start += 1
    return months


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--budget", type=float, required=True, help="max spend per month")
    p.add_argument("--services", default=HERE / "services.json")
    p.add_argument("--watchlist", default=HERE / "watchlist.json")
    args = p.parse_args()

    services, titles = load(args.services, args.watchlist)

    uncovered = [t["title"] for t in titles if not t["services"]]
    if uncovered:
        print(f"Skipping (not on any tracked service): {', '.join(uncovered)}\n")
        titles = [t for t in titles if t["services"]]

    best = cheapest_cover(titles, services, args.budget)
    if best is None:
        sys.exit("No plan fits: some title is only on services priced above the budget.")
    _, assignment, need = best
    months = schedule(titles, services, assignment, need, args.budget)

    for i, month in enumerate(months, 1):
        watching = [t["title"] for t in titles if assignment[t["title"]] in month]
        print(f"Month {i} — ${sum(month.values()):.2f}")
        for s, price in month.items():
            shows = [t for t in watching if assignment[t] == s]
            print(f"  {s:<12} ${price:>6.2f}   {', '.join(shows)}")

    planned = sum(sum(m.values()) for m in months)
    current = sum(s["price"] for s in services.values() if s["current"])
    baseline = current * len(months)
    print(f"\nRotation total over {len(months)} months:     ${planned:.2f}")
    print(f"Keeping current services ({', '.join(s for s in services if services[s]['current'])}):")
    print(f"  ${current:.2f}/mo × {len(months)} months =       ${baseline:.2f}")
    print(f"Estimated savings:                   ${baseline - planned:.2f}")


if __name__ == "__main__":
    main()
