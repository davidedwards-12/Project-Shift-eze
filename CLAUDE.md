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

Prototypes done; no app code yet. Leaning iOS first in SwiftUI, Android later.
When the app project exists, add build, test and lint commands and a
definition of done here. Prototype findings are in `docs/CONCEPT.md`.

`spikes/` holds throwaway feasibility scripts (Python, standard library only).
They read `TMDB_API_KEY` (TMDB's API Read Access Token) from `.env` at the repo
root. `.env` is gitignored; never commit it or print its value.

```bash
python3 -m unittest discover spikes/rotation   # rotation engine rules
python3 spikes/check_links.py                  # management links still resolve
```

Run the tests after any change to `spikes/rotation/`. The test cases pin the
planning rules (renewal timing, link lookup, savings baseline); port them to
the real engine when there is one.

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

- Solo repo, docs and spikes only: committing and pushing straight to `main`
  is fine.
- Once app code exists, switch to a branch per change and a PR into `main`,
  and update this section.
- Short, imperative commit subjects describing what changed.
