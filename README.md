# Project Shift-eze

> **Tell us what you want to watch. We'll figure out what you need.**

*Project Shift-eze is an internal codename. The consumer-facing name hasn't been chosen yet.*

We're building a mobile app that helps people spend less on streaming by **rotating subscriptions** instead of paying for every service all the time.

You give it your watchlist and a monthly budget. It works out which services you need active each month, tells you when to cancel and when to restart, and keeps a running total of how much you've saved.

This is a subscription **optimizer**, not just a subscription tracker.

## How it works

```
Watchlist → Service recommendations → Monthly rotation → Cancel/restart actions → Savings → Repeat
```

1. **Add your subscriptions.** Service, plan, price, renewal date, status (active / paused / inactive), and who bills you (the service itself, Apple, Google, Amazon, Roku, a carrier or cable bundle, and so on).
2. **Build a watchlist.** Search movies, shows, and sports. The app looks up which services carry each title.
3. **Set a budget and get a rotation.** For example, with a $40/month budget:

   | Month     | Services           | Cost |
   | --------- | ------------------ | ---: |
   | September | Netflix, Peacock   |  $35 |
   | October   | Disney+, Hulu      |  $33 |
   | November  | Max, Apple TV+     |  $30 |

4. **Act on it.** Before a renewal, the app tells you whether to keep, cancel, or restart a service and opens the right management page. You finish the change yourself and confirm it in the app.
5. **See your savings.** The dashboard leads with what you've saved this month, this year, and overall, compared with keeping every service running.

## Design principles

- **Savings first.** The dashboard answers "How much am I saving?" before it lists anything else.
- **Semi-automated, not credential-based.** The app never stores streaming passwords. It sends you to the correct cancel or restart page and you complete the step there. Browser automation has too many problems (CAPTCHAs, MFA, changing sites, provider terms, security) to build on. Official partner APIs may allow more automation later.
- **Track who controls the bill.** The company that bills you isn't always the streaming service. The billing provider decides which management link the app sends you to.
- **Deterministic core.** The rotation engine is rules-based optimization, not AI. AI may be added later for natural-language requests, recommendations, and explaining rotations.

## MVP scope

| Area                       | Includes                                                                                  |
| -------------------------- | ----------------------------------------------------------------------------------------- |
| **Subscription tracking**  | Add/edit/delete; price, renewal date, billing provider, status                            |
| **Watchlist**              | Search and add/remove titles; look up where each is available (e.g. via TMDB)             |
| **Rotation planner**       | Monthly budget; build recommended monthly rotations from the watchlist; projected savings |
| **Notifications**          | Upcoming renewals; cancel, restart, and rotation-change reminders                         |
| **Semi-automated actions** | Open the right management page; user confirms; status updates                             |
| **Dashboard**              | Current spend vs. spend without rotation; monthly, yearly, and lifetime savings; upcoming actions |

### Later

Rotation modes (Cheapest, Watchlist, Sports, Family, Binge, Never Pay Unused), household watchlists, spending history, handling for promotions, bundles, and annual plans, and provider partnerships.

## App structure

- **Home**: spending, savings, upcoming actions
- **Services**: active, paused, and inactive subscriptions
- **Watchlist**: movies, TV, sports, search
- **Rotation**: current plan, future months, budget, modes, apply plan
- **Savings**: monthly, yearly, and lifetime savings; spending history

## Business model (tentative)

- **Free**: subscription tracking, renewal reminders, basic spending dashboard
- **Premium** (~$2.99–$4.99/mo or ~$20/yr): automatic rotation planning, watchlist optimization, advanced savings tracking, family, sports, and spending analytics
- **Possible affiliate revenue** from service activations

## Open questions

**Answered by the prototypes** (details in [docs/CONCEPT.md](docs/CONCEPT.md#findings-from-the-prototypes-september-2026)):

- **Feasible?** Yes. Content data, the rotation engine and cancel/restart links all work in prototype.
- **Content source:** TMDB for movies and TV. It doesn't cover sports.
- **Billing providers:** modeled separately from services, with a link list for 8 services and 7 billers.
- **Rotation algorithm:** cheapest set of services covering the watchlist, packed into months under the budget, timed to renewal dates.
- **Platform:** leaning iOS first (SwiftUI), Android later.

**Still open:**

1. How accurate is availability data across a larger, real watchlist?
2. Where does sports availability come from?
3. How should promos, annual plans, bundles, free trials, and Prime membership be handled?
4. Where should the line between free and premium fall?
5. What should the consumer-facing name be?

**The key thing to validate:** do users get enough value from the *watchlist → rotation → savings* loop to come back every month?

## Status

Prototypes done (`spikes/`: TMDB lookup, rotation engine, management links, tests). Next: the iOS app.
