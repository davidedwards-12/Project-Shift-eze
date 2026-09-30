#!/usr/bin/env python3
"""Spike: plan a monthly streaming rotation for a watchlist under a budget.

Usage:
    python3 spikes/rotation/rotate.py --budget 40 [--start 2026-10] [--services FILE] [--watchlist FILE]

Model (v1):
  - Each title must be watched on one service that carries it, for `months`
    consecutive months (default 1).
  - Step 1 picks the cheapest set of services covering every title (exhaustive
    search; fine for ~15 services).
  - Step 2 packs those services into months without exceeding the budget,
    highest-priority titles (earliest in the watchlist) first.
  - Months are calendar months from --start (default: next month). A current
    service's month runs from its `renews` day; a new or restarted service
    starts on the 1st and then renews on the 1st.
  - Upcoming actions list what to keep, cancel and restart, and by when,
    through whoever bills the service.
  - Savings compare average monthly spend: the rotation vs. keeping every
    current service and adding whatever the watchlist needs, never cancelling.
    Monthly, not totals, so a smaller budget that stretches the plan over more
    months doesn't inflate the number.

Not modeled yet: annual plans, promos, bundles, days already paid for before a
cancellation takes effect beyond the half-month rule above, titles that leave a service, new titles mid-plan.
"""

import argparse
import calendar
import datetime
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


def on_day(start, offset, day):
    """Date of `day` in the month `offset` months after `start` (clamped)."""
    y, m = divmod(start.year * 12 + start.month - 1 + offset, 12)
    return datetime.date(y, m + 1, min(day, calendar.monthrange(y, m + 1)[1]))


def actions(services, months, start, today):
    """What to keep, cancel and restart, and by when.

    A renewal on day 1–15 pays for that calendar month; one on day 16+ pays
    mostly for the next month, so it's treated as the start of next month's
    cycle. A restarted or new service renews on the 1st.
    """
    events = []
    for name, s in services.items():
        active = {i for i, m in enumerate(months) if name in m}
        if not s["current"] and not active:
            continue
        via = s.get("billed_through", name)
        day = s.get("renews", 1) if s["current"] else 1
        subscribed, kept = s["current"], False
        for k in range(len(months) + 1):
            renewal = on_day(start, k - (1 if day > 15 else 0), day)
            if renewal < today:
                continue  # already paid for
            if subscribed and k not in active:
                events.append((renewal, f"Cancel {name}", f"before it renews, through {via}"))
                if not active or k > max(active):
                    break
                subscribed = False
            elif subscribed and not kept:
                events.append((renewal, f"Keep {name}", f"renews, billed through {via}"))
                kept = True
            elif not subscribed and k in active:
                verb = "Restart" if s["current"] else "Start"
                day = 1
                events.append((on_day(start, k, 1), f"{verb} {name}", f"through {via}"))
                subscribed, kept = True, True
    return sorted(events)


def main():
    today = datetime.date.today()
    p = argparse.ArgumentParser()
    p.add_argument("--budget", type=float, required=True, help="max spend per month")
    p.add_argument("--start", help="first month of the plan, YYYY-MM (default: next month)")
    p.add_argument("--services", default=HERE / "services.json")
    p.add_argument("--watchlist", default=HERE / "watchlist.json")
    args = p.parse_args()

    if args.start:
        start = datetime.datetime.strptime(args.start, "%Y-%m").date()
    else:
        start = on_day(today.replace(day=1), 1, 1)

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

    for i, month in enumerate(months):
        watching = [t["title"] for t in titles if assignment[t["title"]] in month]
        print(f"{on_day(start, i, 1):%B %Y} — ${sum(month.values()):.2f}")
        for s, price in month.items():
            shows = [t for t in watching if assignment[t] == s]
            print(f"  {s:<12} ${price:>6.2f}   {', '.join(shows)}")

    print("\nUpcoming actions")
    for when, what, how in actions(services, months, start, today):
        print(f"  {when:%b %d}  {what:<22} {how}")

    current = [n for n, s in services.items() if s["current"]]
    added = [n for n in need if not services[n]["current"]]
    baseline = sum(services[n]["price"] for n in current + added)
    planned = sum(sum(m.values()) for m in months)
    average = planned / len(months)
    kept = ", ".join(current) + (f", + {', '.join(added)}" if added else "")
    print(f"\nWithout rotation ({kept}):  ${baseline:.2f}/mo")
    print(f"With rotation: ${planned:.2f} over {len(months)} months =  ${average:.2f}/mo")
    print(f"Estimated savings:  ${baseline - average:.2f}/mo  (≈ ${(baseline - average) * 12:.0f}/yr)")


if __name__ == "__main__":
    main()
