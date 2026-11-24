# Anchor agent notes

Anchor is an offline-first, self-hostable note taking app. Three parts, each
with its own toolchain:

| Path | What | Stack |
| --- | --- | --- |
| `server/` | API and sync | NestJS, Prisma, PostgreSQL |
| `web/` | Web app | Next.js |
| `mobile/` | Android and iOS app | Flutter, drift |
| `design/` | Design tokens (source of truth) | W3C Design Tokens |

Checks before calling work done:

```
cd server && pnpm check && pnpm test
cd web    && pnpm check && pnpm test
cd mobile && flutter analyze && flutter test
```

After changing a design token, run `node design/build/build.mjs` from the repo
root; CI fails when the generated files are out of date.

## Contribution rules (keep terse; full text in upstream)

- **Commits / PRs**: Conventional Commits `type(scope): what`. `type` is one of
  feat, fix, perf, docs, refactor, test, chore, ci, build. `scope` is one of
  web, mobile, server. One PR does one thing; no mixing fix + refactor + format.
- **l10n**: app-facing strings go in `mobile/lib/l10n/app_en.arb` with an
  `@key.description`; never hard-code a string in code. The generated
  `app_localizations.dart` + `_en.dart` are patched by hand (single locale).
- **Checks**: `cd mobile && flutter analyze && flutter test`; format with
  `dart format lib test`. Stage only the files you touched (no `git add -A`).
- **Design tokens**: edit `design/tokens/`, then run the build (generated
  files are checked).
- **AI policy**: AI may be used; a human is fully accountable. Never list an
  AI/agent as author or co-author on a commit or PR; name the tool in the PR
  body.
- **Visual proof**: for visible changes, attach before/after screenshots in
  light and dark.

## Agent skills

### Issue tracker

Issues live as markdown files under `.scratch/<feature-slug>/`. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Fork, build and release notes (for new sessions)

- **Remotes**: `origin` = `zhfahim/anchor` (upstream), `fork` = `muava12/anchor`
  (our working fork). Branch from `fork/main`; open PRs with
  `gh pr create --repo muava12/anchor ...` (gh defaults to `origin`).
- **Flutter is remote**: never run `flutter` locally. Use `rflutter`
  (instance `box05`, host box-05 over ssh): analyze, test, build. A new git
  worktree means a new remote workspace; the first sync takes minutes.
- **CI gates**: `mobile-android` compiles the Kotlin/Android code (no Android
  SDK on box-05). `mobile-lint` runs analyze + tests, and carries two
  pre-existing coffee-link failures (`debug_coffee_test.dart`,
  `settings_editor_test.dart`) that are not a blocker.
- **Native reminder system** (fork-only, `mobile/android/.../reminders/`):
  `FullScreenReminderActivity` (FSI sheet), `SnoozeReminderActivity`
  (standalone snooze sheet), `ReminderActionReceiver`, `SnoozeScheduleHelper`,
  `PendingSnoozeStore`; both sheets share the translucent `Theme.FsiActivity`.
  Design-first flow: edit the Doop frame first (canvas `-IAXF4NORn` via the
  mcpproxy `doop:*` tools; frames `nx07-wSkMw` reminder, `Wn02ojCMhA` snooze,
  `7zq4fCi8lr` thumbnail knob; style guide `anchor-shadow-motion`), then code
  against it.
- **Releases**: branch, then PR, then merge into `fork/main`, then tag `vX.Y.Z`,
  which runs `release.yml` (signed via the `ANDROID_KEYSTORE_BASE64` keystore,
  package `moek.anchor.notex`). On-demand test APKs: the `build-test-apk.yml`
  workflow dispatch, hosted on box-05's instabox URL.
- **Fix-round records** live in `.scratch/<slug>/` (`collect.md` = items +
  root causes, `plan.md` = execution plan); round 01 is
  `.scratch/fix-round-01/`.
- Show GitHub/API timestamps to the owner in WITA (UTC+8), not UTC.
