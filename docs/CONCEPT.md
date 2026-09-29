# Project Shift-eze — Product Concept

*"Project Shift-eze" is an internal codename. The consumer-facing name is
undecided (see [Naming](#naming)).*

## Concept

An app that helps people **spend less on streaming services by intelligently
rotating their subscriptions**.

The app is not just a subscription tracker. The core idea is:

> **Tell the app what you want to watch and your monthly budget, and it
> determines which streaming services you actually need active each month.**

For example:

> "This month I want Netflix and Peacock. Next month I want Disney+ and Hulu."

Instead of paying for every streaming service continuously, the app creates a
monthly rotation based on the user's watchlist, budget, subscription prices, and
renewal dates.

The ultimate goal is:

> **Watch what you want without paying for subscriptions you're not using.**

## Core user flow

### 1. Add subscriptions

The user enters their current streaming services. For each service, the app
tracks:

- Service name
- Plan
- Monthly price
- Renewal/billing date
- Active/inactive/paused status
- Billing provider
- Management/cancellation URL
- Promotional pricing or bundle information where applicable

| Service | Price  | Status   | Renews   | Billed Through |
| ------- | -----: | -------- | -------- | -------------- |
| Netflix | $24.99 | Active   | Sept. 22 | Apple          |
| Max     | $16.99 | Active   | Sept. 28 | Max            |
| Disney+ | $15.99 | Paused   | Oct. 1   | Disney+        |
| Peacock | $10.99 | Inactive | —        | Comcast        |

### 2. Build a watchlist

The user searches for movies, TV shows, and sports they want to watch (e.g.
Stranger Things, The Last of Us, Severance, Andor, Premier League).

The app uses a service/content database such as **TMDB** to determine which
services currently offer each piece of content. The watchlist is the input for
the rotation engine.

### 3. Create a rotation

The user chooses a budget, e.g. **$40/month**. The app analyzes the watchlist
and available services and generates an efficient subscription schedule:

- **September — $35:** Netflix, Peacock
- **October — $33:** Disney+, Hulu
- **November — $30:** Max, Apple TV+

The goal is to minimize unnecessary overlapping subscriptions while still
letting the user watch what they want.

## Rotation modes

- **Cheapest:** lowest-cost combination of services that covers the watchlist.
- **Watchlist:** prioritize services based on desired movies/shows.
- **Sports:** optimize around seasonal sports.
- **Family:** account for multiple household members' watchlists.
- **Binge:** subscribe to a service for one month for a specific show or
  collection.
- **Never Pay Unused:** identify subscriptions that appear unused and recommend
  cancelling them.

## Dashboard

Savings are the centerpiece. Instead of listing subscriptions, the dashboard
answers: **How much money am I saving by rotating subscriptions?**

> ### You've saved $40.97 this month
>
> **Current spending:** $41.98/month
> **Estimated spending without rotation:** $82.95/month
> **Estimated savings:** $40.97/month

Also: **"You've saved $491.64 this year."** This accumulated savings number is
an important retention mechanic and potentially the main reason users keep using
the app.

### Upcoming actions

| Service | Date            | Action  |
| ------- | --------------- | ------- |
| Netflix | Renews Sept. 22 | Keep    |
| Max     | Renews Sept. 28 | Cancel  |
| Disney+ | Restart Oct. 1  | Restart |

The app proactively notifies the user when an action is approaching.

## Cancellation / restart flow

Most streaming services have no universal API for third-party apps to cancel,
pause, or restart subscriptions, so the initial product is **semi-automated**:

> **Your Max subscription renews tomorrow.** Your current rotation doesn't
> require Max next month. Cancel Max?

The user taps **Cancel Max**, the app opens the correct subscription-management
page (accounting for whether it's billed directly or through Apple, Google,
Amazon, Roku, Verizon, Comcast, etc.), the user completes the cancellation, and
the app records the subscription as inactive. Restarting works the same way.

### Important principle

Do **not** require the app to store users' streaming passwords. Browser
automation may eventually be possible but should not be the foundation of the
MVP because of CAPTCHAs, MFA, changing provider websites, provider
restrictions, security concerns, and credential storage.

The initial experience is simply: **We tell you what to cancel and take you
directly to the correct page.** Official provider partnerships/APIs could allow
more automation later.

## Billing provider problem

The streaming service isn't necessarily the company controlling the
subscription. It may be billed through Apple, Google Play, Amazon, Roku,
Verizon, Comcast, another bundle/provider, or the service directly.

The app must track **who actually controls the subscription**, and the action
system uses that to send the user to the correct management page.

## Core navigation

- **Home:** spending, savings, upcoming actions
- **Services:** active, paused, inactive subscriptions
- **Watchlist:** movies, TV, sports, search/add content
- **Rotation:** current plan, future months, budget, rotation modes, apply
  recommended plan
- **Savings:** monthly, yearly, lifetime savings; spending history

## MVP

- **Subscription tracking:** add/edit/delete; price; renewal date; billing
  provider; active/inactive status
- **Watchlist:** search content; add/remove; determine available services
  (TMDB or another content database)
- **Rotation planner:** set monthly budget; analyze watchlist; calculate service
  combinations; recommend monthly rotations; calculate projected savings
- **Notifications:** upcoming renewals; cancellation, restart, and
  rotation-change reminders
- **Semi-automated actions:** open the correct cancellation/management or
  restart page; let the user confirm completion; update subscription status
- **Dashboard:** current monthly spending; estimated unmanaged spending;
  monthly, yearly, and lifetime savings; upcoming actions

## Technology

The app does **not** need AI at its core. The initial rotation engine can be
rules-based:

```text
User Watchlist → Content availability → Streaming services → Service
combinations → Prices → Renewal dates → Monthly budget → Optimal rotation
```

AI could eventually be used for natural-language watch requests, personalized
recommendations, explaining why a rotation was chosen, predicting what the user
will want to watch, and conversational subscription management. The fundamental
optimization problem can be solved deterministically.

## Business model

- **Free:** subscription tracking, renewal reminders, basic spending dashboard
- **Premium** (~$2.99–$4.99/month or ~$20/year): automatic rotation planning,
  watchlist optimization, advanced savings tracking, family accounts, sports
  optimization, more advanced notifications, historical spending analytics
- **Affiliate revenue** from streaming-service activations as a possible
  additional stream

## Long-term vision

Evolve from a **subscription tracker** into an **automated streaming
subscription optimizer**:

1. User tells the app what they want to watch.
2. App knows what subscriptions they have.
3. App knows where their subscriptions are billed.
4. App knows renewal dates and prices.
5. App determines what services they actually need.
6. App tells them what to cancel.
7. App tells them what to restart.
8. Eventually, partnerships/APIs allow some actions to happen automatically.
9. App continuously tracks how much money the user has saved.

The ideal experience:

> **"You've finished your Netflix watchlist. Your Netflix billing cycle ends
> September 22. Switch Netflix → Max and save $22 this month."**

The strongest retention mechanic is cumulative savings: **"You've saved $286
this year."**

## Positioning

**Not:** "Track your subscriptions."

**Instead:** **"Only pay for the streaming services you're actually using."**
or **"Tell us what you want to watch. We'll figure out what you need."**

Core loop: **Watchlist → Service recommendations → Subscription rotation →
Cancellation/restart actions → Savings → Repeat**

## Naming

The original working concept was called **The Big Bang**; the repo codename is
**Project Shift-eze**. Neither is the consumer-facing name.

Previously considered:

| Name        | Status                            |
| ----------- | --------------------------------- |
| StreamShift | Taken on the App Store            |
| BingeT      | Taken on the App Store            |
| StreamWise  | Problematic / already used        |
| SubSave     | Already used                      |
| SubPilot    | Already used                      |
| SubShift    | Already used                      |
| StreamDeck  | Associated with Elgato            |
| OnDeck      | Already used                      |
| WatchWise   | Already used                      |
| SmartStream | Unchecked                         |
| FlexStream  | Unchecked                         |
| StreamCycle | Unchecked                         |
| StreamLoop  | Unchecked                         |
| StreamHop   | Unchecked                         |
| BingeHop    | Unchecked                         |
| BingeCycle  | Unchecked                         |
| StreamFlip  | Unchecked                         |

## Open questions

1. Is the concept technically feasible as an MVP?
2. Which content database/API should be used?
3. How accurately can the app determine where content is available?
4. How should billing providers be represented?
5. What subscription-management URLs/deep links are available for each
   provider?
6. Which platforms first — iOS, Android, or both?
7. What is the minimum viable rotation algorithm?
8. How should the app handle price changes, promotions, annual plans, bundles,
   and free trials?
9. How much automation is realistically possible without official provider
   APIs?
10. What should be free vs. premium?
11. What is the best consumer-facing name/brand?

**Most important to validate:** whether users find enough value in the
**watchlist → rotation → savings** loop to use the app repeatedly.
