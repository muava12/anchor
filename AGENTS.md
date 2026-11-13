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

## Agent skills

### Issue tracker

Issues live as markdown files under `.scratch/<feature-slug>/`. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
