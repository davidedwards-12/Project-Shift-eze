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

1. Is the MVP technically feasible end to end?
2. Which content-availability source (TMDB / JustWatch data, others), and how accurate is it?
3. How should billing providers be modeled?
4. Which management URLs and deep links exist for each service and billing provider?
5. Which platform ships first: iOS, Android, or both?
6. What's the minimum viable rotation algorithm?
7. How should price changes, promos, annual plans, bundles, and free trials be handled?
8. How much can realistically be automated without provider APIs?
9. Where should the line between free and premium fall?
10. What should the consumer-facing name be?

**The key thing to validate:** do users get enough value from the *watchlist → rotation → savings* loop to come back every month?

## Status

Early concept and planning. No code yet.
