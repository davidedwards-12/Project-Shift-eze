# CLAUDE.md — Project Shift-eze

Guidance for Claude Code working in this repository
(`davidedwards-12/Project-Shift-eze` on GitHub).

## What this is

"Project Shift-eze" is an internal codename, like "Project X". It is not the
product name and must not appear as one in user-facing copy, app strings or
store listings. The consumer-facing name is **FlixShift** (one word, capital
F and S).

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
up without editing the project. Layout: `App/` (entry point, `AppModel`,
config), `Features/<Plan|Services|Watchlist|Onboarding|About>/` (one folder per
tab or flow, with its screens), `Notifications/`, `Support/` (formatting,
theme) and `Resources/` (assets, sample data). New screens go in the
matching feature folder. Tabs: Plan, Services, Watchlist. `AppModel`
holds subscriptions, watchlist, budget and the Prime setting, saves on every
change, and recomputes `RotationPlan` on every read.

Saving lives in the package's `Persistence` target (tested by `swift test`):
`SavedState` is written as JSON to Application Support/`state.json` with iOS
file protection. First launch starts from `ShiftEze/Resources/SampleData/`. Out-of-range
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

Reminders are local notifications only: no push, no server, nothing leaves
the phone. `Reminders.make` (engine) picks what to remind and when: cancels 2
days before the renewal (or today if sooner), starts and restarts on the day,
no reminder for keeps, skipping past actions. `ReminderScheduler` (app)
turns them into notifications at 9am local time and reschedules whenever the
plan changes; iOS allows 64 pending, so at most 60 are scheduled. Permission
is asked once onboarding is done and there's something to remind about.
`NotificationHandler` opens the cancel/restart page when one is tapped. Action
ids (`cancel-Netflix-2026-10-22`) are stable across launches.

Marking an action done (swipe left → Done) changes the user's subscriptions
via `SubscriptionChanges.apply`: a cancel makes the service not current (paid
up until the renewal date), a start/restart makes it current, renewing on the
day it was done. Each change is saved in `SavedState.changes` with the
previous settings, so "Done recently" on the Plan tab can undo it; it's also
the history actual savings are worked out from.

Actual savings ("You've saved $X this year", top of the Plan tab) come from
`ActualSavings.summary`: what the `Baseline` subscriptions would have charged
on their billing days since `baseline.since`, minus what was really charged
(current subscriptions rewound through `changes`), up to today. Rotated-in
services count against savings. The baseline is a snapshot of current
subscriptions taken when onboarding finishes (or on first launch for older
installs) and is editable under "What you paid before". Charges use each
service's current price. The projected plan figure stays below as "This plan".
`SavedState.init` has no default arguments on purpose: a new field must be
passed explicitly so it can't be dropped when saving.

App colors come from `ShiftEze/Support/Theme.swift`: roles like `Theme.accent`,
`Theme.background` and `Theme.gradient`, with values from `docs/BRAND.md`.
Don't use raw hex in views. The app is dark only. Every `List`/`Form` gets
`.themedList()` with its contents wrapped in a `Group` carrying
`.themedRows()`; full-width `.borderedProminent` buttons use
`.primaryButtonLabel()` on their label. The gradient is for hero elements
(the savings card, the app icon). The app icon is a placeholder until there's
a logo.

The ⓘ button on the Plan tab opens `AboutView` (`Features/About/`): version,
a short privacy summary, the TMDB and JustWatch credits their terms require,
the contact address and a link to the public policy
(`https://flixshift.app/privacy/`). The full policy is `Resources/PrivacyPolicy.md`,
bundled and shown by `PrivacyPolicyView`, so there's one copy of the wording;
it only understands `#`/`###` headings, `-` bullets and inline Markdown. The
policy must be updated before any change to what leaves the phone ships (for
example moving TMDB calls to a server).

`site/` is the public website for `flixshift.app`, deployed by Cloudflare
(set up by Dave) with `npx wrangler deploy` from the top of the repo on every
push to `master`; `wrangler.jsonc` says to serve `site/public/`. The Worker
has no root directory set in Cloudflare; keep it that way. Pull requests get a
temporary preview address from `npx wrangler preview`, which needs the
`previews` block in `wrangler.jsonc`. `.github/workflows/preview.yml` waits until that
preview serves the PR's files (`.github/scripts/wait_for_preview.py`), then
posts the link as a PR comment, updated on each push. It's plain HTML
and CSS: no JavaScript, no tracking, no outside requests, with security
headers in `public/_headers`. `public/privacy/index.html` is generated from
the app's `PrivacyPolicy.md` by `python3 site/build.py`; rerun it after
editing the policy (CI fails if it's out of date). Preview with
`python3 -m http.server --directory site/public`. The contact address everywhere is
`support@flixshift.app`.

The display name is "FlixShift" and the bundle ID is `com.doubled.flixshift`
(DoubleD is Dave and Daniel). The Xcode project, target and source folder are
still named `ShiftEze`; that's internal and users never see it. The codename
must not become the display name.

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
the Python spike tests on every PR and push to `master`; a newer push cancels
the older run. Each run writes a summary on its page (tests per area, Swift
line coverage per target and per file) via `.github/scripts/swift_summary.py`
and `python_tests.py`; coverage is reported, not enforced. The Mac jobs use
the `xcode-27` runner image with Xcode pinned via `XCODE_APP` (the version the
team builds with locally); upgrade it there
deliberately. `.github/workflows/links.yml` runs `spikes/check_links.py`
every Monday and can be started by hand from the Actions tab. The Python job also
checks the website's privacy page is up to date with the app's policy. The TMDB key is
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

- App code exists now: one branch per change and a PR into `master`. Don't
  commit app code straight to `master`.
- `master` is protected: PRs need the Swift engine, iOS app build and Python
  spike checks to pass before merging. Admins (Dave) can still push docs-only
  changes straight to `master`; everyone else goes through a PR. No force
  pushes or deleting `master`.
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
