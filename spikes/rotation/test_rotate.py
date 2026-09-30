"""Tests for the rotation spike. These pin down the planning rules so the real
engine can be checked against the same cases.

Run: python3 -m unittest discover spikes/rotation
"""

import datetime
import unittest

import rotate

START = datetime.date(2026, 10, 1)   # plan begins October 2026
TODAY = datetime.date(2026, 9, 29)


def service(name, price, current=False, renews=None, via=None, aliases=()):
    s = {"name": name, "price": price, "current": current, "aliases": list(aliases)}
    if renews:
        s["renews"] = renews
    if via:
        s["billed_through"] = via
    return s


def plan_actions(services, months):
    """Actions as (date, action) pairs, links dropped."""
    by_name = {s["name"]: s for s in services}
    return [(d, what) for d, what, _, _ in rotate.actions(by_name, months, START, TODAY)]


def d(month, day):
    year = 2026 if month >= 9 else 2027
    return datetime.date(year, month, day)


class RenewalActions(unittest.TestCase):
    def test_late_month_renewal_is_kept_for_next_month(self):
        # HBO Max renews on the 28th and is needed in November: the Oct 28
        # renewal covers November, so keep it rather than cancel + restart.
        hbo = service("HBO Max", 16.99, current=True, renews=28)
        self.assertEqual(
            plan_actions([hbo], [{}, {"HBO Max": 16.99}]),
            [(d(10, 28), "Keep HBO Max"), (d(11, 28), "Cancel HBO Max")],
        )

    def test_late_month_renewal_already_covers_first_month(self):
        # Netflix renewed Sep 22, which pays for October: cancel before Oct 22.
        netflix = service("Netflix", 24.99, current=True, renews=22)
        self.assertEqual(
            plan_actions([netflix], [{"Netflix": 24.99}]),
            [(d(10, 22), "Cancel Netflix")],
        )

    def test_cancel_restart_cancel(self):
        disney = service("Disney+", 15.99, current=True, renews=1)
        self.assertEqual(
            plan_actions([disney], [{}, {"Disney+": 15.99}, {}]),
            [(d(10, 1), "Cancel Disney+"), (d(11, 1), "Restart Disney+"), (d(12, 1), "Cancel Disney+")],
        )

    def test_new_service_starts_on_the_first(self):
        prime = service("Prime Video", 8.99)
        self.assertEqual(
            plan_actions([prime], [{}, {}, {"Prime Video": 8.99}]),
            [(d(12, 1), "Start Prime Video"), (d(1, 1), "Cancel Prime Video")],
        )

    def test_unneeded_current_service_is_cancelled_once(self):
        peacock = service("Peacock", 12.99, current=True, renews=15)
        self.assertEqual(plan_actions([peacock], [{}, {}]), [(d(10, 15), "Cancel Peacock")])

    def test_unneeded_non_current_service_has_no_actions(self):
        self.assertEqual(plan_actions([service("Hulu", 18.99)], [{}]), [])


class Planning(unittest.TestCase):
    SERVICES = [
        service("Netflix", 24.99, current=True, aliases=["Netflix Standard with Ads"]),
        service("Disney+", 15.99, current=True, aliases=["Disney Plus"]),
        service("Hulu", 18.99),
        service("Prime Video", 8.99, aliases=["Amazon Prime Video"]),
    ]
    TITLES = [
        {"title": "Andor", "services": ["Disney Plus"]},
        {"title": "The Bear", "services": ["Hulu", "Disney Plus"]},
        {"title": "Stranger Things", "services": ["Netflix Standard with Ads", "Spectrum On Demand"], "months": 2},
        {"title": "Reacher", "services": ["Amazon Prime Video"]},
    ]

    def plan(self, budget):
        services, titles = rotate.prepare(self.SERVICES, self.TITLES)
        best = rotate.cheapest_cover(titles, services, budget)
        _, assignment, need = best
        return services, titles, assignment, need, rotate.schedule(titles, services, assignment, need, budget)

    def test_provider_names_are_normalized_and_unknown_ones_dropped(self):
        _, titles = rotate.prepare(self.SERVICES, self.TITLES)
        self.assertEqual(titles[2]["services"], ["Netflix"])  # alias mapped, Spectrum dropped

    def test_reuses_a_needed_service_instead_of_adding_another(self):
        # The Bear is on Hulu and Disney+; Andor already needs Disney+.
        _, _, assignment, need, _ = self.plan(40)
        self.assertEqual(assignment["The Bear"], "Disney+")
        self.assertNotIn("Hulu", need)

    def test_months_never_exceed_budget(self):
        for budget in (25, 40, 60):
            *_, months = self.plan(budget)
            for m in months:
                self.assertLessEqual(sum(m.values()), budget + 1e-9)

    def test_multi_month_title_gets_consecutive_months(self):
        *_, months = self.plan(25)
        active = [i for i, m in enumerate(months) if "Netflix" in m]
        self.assertEqual(len(active), 2)
        self.assertEqual(active[1] - active[0], 1)

    def test_no_plan_when_budget_is_below_a_required_service(self):
        services, titles = rotate.prepare(self.SERVICES, self.TITLES)
        self.assertIsNone(rotate.cheapest_cover(titles, services, 10))

    def test_savings_baseline_does_not_depend_on_budget(self):
        results = []
        for budget in (25, 60):
            services, _, _, need, months = self.plan(budget)
            baseline, average, added = rotate.savings(services, need, months)
            results.append((baseline, round(average * len(months), 2), added))
        (b1, total1, added1), (b2, total2, added2) = results
        self.assertEqual(b1, b2)            # same baseline
        self.assertEqual(total1, total2)    # same total spend, just spread differently
        self.assertEqual(added1, ["Prime Video"])  # baseline includes needed non-current services
        self.assertAlmostEqual(b1, 24.99 + 15.99 + 8.99)


class ManagementLinks(unittest.TestCase):
    def link(self, service, biller):
        return rotate.management_link(rotate.LINKS, service, biller)

    def test_direct_billing_uses_the_service_page(self):
        self.assertEqual(self.link("Peacock", "Peacock"), "https://www.peacocktv.com/account/plans")

    def test_third_party_billing_uses_the_billers_page(self):
        self.assertEqual(self.link("Netflix", "Apple"), rotate.LINKS["billers"]["Apple"]["web"])

    def test_biller_aliases(self):
        self.assertEqual(self.link("Peacock", "Comcast"), rotate.LINKS["billers"]["Xfinity"]["web"])
        self.assertEqual(self.link("HBO Max", "Amazon Channels"), rotate.LINKS["billers"]["Amazon"]["web"])

    def test_roku_exception_sends_disney_and_hulu_to_the_service(self):
        self.assertEqual(self.link("Disney+", "Roku"), rotate.LINKS["services"]["Disney+"]["manage"])
        self.assertEqual(self.link("Hulu", "Roku"), rotate.LINKS["services"]["Hulu"]["manage"])
        self.assertEqual(self.link("Peacock", "Roku"), rotate.LINKS["billers"]["Roku"]["web"])

    def test_unknown_biller_falls_back_to_the_service_page(self):
        self.assertEqual(self.link("Netflix", "Some Cable Co"), rotate.LINKS["services"]["Netflix"]["manage"])


if __name__ == "__main__":
    unittest.main()
