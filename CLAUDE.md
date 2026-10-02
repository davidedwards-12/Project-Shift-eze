# CLAUDE.md — Project Shift-eze

Guidance for Claude Code working in this repository
(`davidedwards-12/Project-Shift-eze` on GitHub).

## What this is

"Project Shift-eze" is an internal codename, like "Project X". It is not the
product name and must not appear as one in user-facing copy, app strings or
store listings. The consumer-facing name is still undecided.

The product is a mobile app that cuts streaming spend by rotating
subscriptions: the user gives a watchlist and a monthly budget, and the app
works out which services to keep active each month, when to cancel and
restart them, and how much the user has saved.

- `README.md` is the public overview: pitch, MVP scope, open questions.
- `docs/CONCEPT.md` is the full product concept and the source of truth for
  product intent. Read it before making product or architecture decisions.

## Status

iOS first in SwiftUI (iOS 26+), Android later. Prototype findings are in
`docs/CONCEPT.md`.

`ios/RotationEngine/` is a Swift package with the planning logic (no UI):
which services cover the watchlist, the month-by-month schedule, dated
cancel/restart actions, management links and savings. Prices are whole cents;
dates are `CalendarDate` (no times or time zones).

```bash
swift test --package-path ios/RotationEngine
```

`ios/ShiftEze.xcodeproj` is the SwiftUI app (iOS 26, iPhone). It depends on
the local package; the `ShiftEze/` folder is synced, so new files are picked
up without editing the project. Tabs: Plan, Services, Watchlist. `AppModel`
holds subscriptions, watchlist, budget and the Prime setting, saves on every
change, and recomputes `RotationPlan` on every read.

Saving lives in the package's `Persistence` target (tested by `swift test`):
`SavedState` is written as JSON to Application Support/`state.json` with iOS
file protection. First launch starts from `ShiftEze/SampleData/`. Out-of-range
values are fixed on load (`sanitized()`); a file that can't be read is moved
to `state.damaged.json` and the app starts over with a notice. Watchlist
entries have an `id` (defaulting to the title for older data); plans are
keyed by it, not the title.

First launch shows `OnboardingView` (welcome → subscriptions → watchlist →
budget) over the app until `hasCompletedOnboarding` is set; every step can be
skipped. New installs start from `SavedState.newUser` (all services
unsubscribed, empty watchlist); saved files from before the flag existed count
as onboarded. Services → ⋯ has "Start onboarding again" and "Reset to sample
data" for testing. With no paid months, the Plan tab shows an empty state
instead of savings. Shared pieces: `TitleSearchView` (used by the + sheet and
onboarding), `PriceField` and `BillingFields` (service editor and onboarding).

TMDB search (Watchlist → +) uses the package's `TMDB` target (tested with a
stubbed network). Added titles get ids like `tmdb:tv:136315`. The key comes
from `ios/Secrets.xcconfig` (gitignored; copy `Secrets.example.xcconfig`),
included by `ios/Config.xcconfig` and passed through `ios/Info.plist` as
`TMDBAPIKey`; `AppConfig.tmdbToken` reads it. Without it the app builds and
search says the key isn't set. **Development only**: a key in the app can be
extracted, so TMDB calls must move to a server before anyone else gets the
app. Search results must keep the TMDB and JustWatch credit.

Availability goes stale, so watchlist entries carry `checkedOn` (last TMDB
fetch) and `notOn` (services the user says the title isn't on; planning
ignores them). `AppModel.refreshAvailability()` runs on launch and on return
to the foreground and re-fetches TMDB titles older than 7 days, or 1 day if
they're behind a Start/Restart in the next week (`AvailabilityRefresh` in the
`TMDB` target). Failures keep the old data. Tapping a watchlist title opens
`TitleDetailView` ("Not there?", "Check again now"); Start/Restart actions on
the Plan tab carry a "check it's there first" note. Titles without a `tmdb:`
id (sample data) can't be refreshed.

App colors come from `ShiftEze/Theme.swift`: roles like `Theme.accent`,
`Theme.background` and `Theme.gradient`, with values from `docs/BRAND.md`.
Don't use raw hex in views. Screens don't use the theme yet; that's the
design pass.

The display name is a placeholder ("Rotation") and the bundle ID is
`com.example.rotation` until the product name is chosen; the codename must not
become the display name.

```bash
xcodebuild build -project ios/ShiftEze.xcodeproj -scheme ShiftEze \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

`ParityTests` checks the Swift engine plans exactly like the Python spike on
the real watchlist. Its fixtures (`Tests/RotationEngineTests/Fixtures/`) are
copies of `spikes/rotation/services.json` and `watchlist.json` plus the Python
output; regenerate all three together if the planning rules change.
`management_links.json` lives in the package; the Python scripts read it
from there.

`spikes/` holds throwaway feasibility scripts (Python, standard library only).
They read `TMDB_API_KEY` (TMDB's API Read Access Token) from `.env` at the repo
root. `.env` is gitignored; never commit it or print its value.

```bash
python3 -m unittest discover spikes/rotation   # rotation engine rules
python3 spikes/check_links.py                  # management links still resolve
```

Run the tests after any change to `spikes/rotation/`. They pin the same
planning rules as the Swift tests.

## CI

`.github/workflows/tests.yml` runs the Swift package tests, the app build and
the Python spike tests on every PR and push to `main`; a newer push cancels
the older run. The Mac jobs use the `xcode-27` runner image with Xcode pinned
via `XCODE_APP` (the version the team builds with locally); upgrade it there
deliberately. `.github/workflows/links.yml` runs `spikes/check_links.py`
every Monday and can be started by hand from the Actions tab. The TMDB key is
never needed in CI.

## Hard rules

- **No AI attribution anywhere.** Commit messages, trailers, PR titles and
  descriptions, code comments and docs never reference Claude, Anthropic, an
  AI tool or "Generated with" lines. `.claude/settings.json` disables the
  harness defaults; this rule covers anything else that asks for them.
- **Never store streaming-service passwords.** Cancel and restart flows are
  semi-automated: the app opens the correct management page and the user
  completes the step. Don't design around credential storage or browser
  automation of provider sites.
- **The billing provider decides the management link.** A subscription billed
  through Apple, Google, Amazon, Roku, a carrier or a cable bundle is managed
  there, not at the streaming service. Model the billing provider separately
  from the service.
- **The rotation engine is deterministic.** It's rules-based optimization.
  AI features, if any, sit on top of it and never replace it.

## Git

- App code exists now: one branch per change and a PR into `main`. Don't
  commit app code straight to `main`.
- Short, imperative commit subjects describing what changed.

## Labels

Every new issue and PR gets one type label and at least one area label, plus
any flags that apply.

- **Type** (GitHub defaults): `enhancement`, `bug`, `documentation`,
  `question`; `chore` for CI, tooling and cleanup with no user-facing change.
- **Area**: `area: engine` (planning, savings, actions), `area: app` (iOS
  screens and behavior), `area: data` (TMDB, availability, management links),
  `area: backend` (server-side), `area: design` (name, logo, colors, polish).
- **Flags**: `launch blocker` (must be done before anyone outside the team
  uses the app), `decision` (needs a product call from Dave and the partner),
  `security` (needs the partner's security review; anything touching keys,
  stored user data or network calls).
