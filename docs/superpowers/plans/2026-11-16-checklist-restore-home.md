# P2 Plan: checklist restore-home (check uncheck anak → balik ke induk)

**Spec:** `docs/superpowers/specs/2026-11-16-checklist-restore-home-design.md` (approved)
**Scope:** `mobile/` only. No server/web changes.

## Design decisions (my calls, per spec)

- Keys: `anchor-id`, `anchor-home` (prefixed, no Quill clash).
- `anchor-id`: short random base36, written to every checklist line in the
  group that lacks one, at sort time (not at line-creation time, so there are fewer
  touch points).
- `anchor-home` (on a block head only): `"{parentId}|{indentAtMove}"`.
  Written when a fully-checked block moves to the checked section. Cleared
  (attr `false`) when the head moves with no checklist parent above it.
- On uncheck: `prefer` block reads its home; parent line found in group by
  id, parent checklist + unchecked → insert after parent's block end (in
  the open list), indent = stored home indent. Otherwise → fallback to
  current behavior (open list tail, current indent).
- Home/ids compose into the same delta as move+reindent → one undo step.
- `retain` with `{key: value}` merges; `{key: false}` removes (Quill attr
  removal). Existing `buildIndentsDelta`/toggle retains already merge, so
  home/ids survive.

## Tasks

- [ ] **T1** `document_lines.dart`: ParsedLine getters `anchorId` /
      `anchorHome`; key constants + `newAnchorId()` + home encode/parse in
      `checklist_lines.dart`. Unit tests: getters + encode/parse round
      trip.
- [ ] **T2** `checklistCheckedSectionPlan`: generate ids, write home on
      moved blocks, home-based insert on uncheck. Tests:
      - check child A1 → plan moves it to done, home written (A1: A.id|1)
      - uncheck A1 → plan places A1 after A's block, indent 1 (under A)
      - parent deleted/checked → fallback (tail of open list)
      - legacy lines without ids → fallback
- [ ] **T3** `buildCheckedSectionDelta`: compose the attr patch (ids +
      homes) after move+reindent. Test: full check→uncheck round trip on a
      `Document`, assert final order + indents + attrs, and that a second
      check→uncheck round trip still lands under A (ids persist).
- [ ] **T4** `checklist_reorder_test.dart` (sorter level): cascade
      check/uncheck round trip through `ChecklistSorter` with `compose`
      override; assert undo step count stays 1 per toggle.
- [ ] `flutter analyze` + `flutter test` green (rflutter).
