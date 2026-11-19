# Anchor — agent notes

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

- **Commits / PRs**: Conventional Commits `type(scope): what` —
  `type` ∈ feat,fix,perf,docs,refactor,test,chore,ci,build; `scope` ∈ web,mobile,server.
  One PR does one thing; no mixing fix + refactor + format.
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
