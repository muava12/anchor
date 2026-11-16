# Design — restore a checked child to its parent on uncheck (P2)

Status: proposed. Awaiting owner approval.

## Problem

Example group (fork `main`, after v0.25.2):

```
[] A
    [] A1
    [] A2
[] B
    [] B1
    [] B2
[] C
> Checked
[] D
    [] D1
```

Current fork behavior when **checking A1**:
- A1 is fully checked → moved to the checked section at the group bottom,
  and its indent is **flattened to absolute 0** (`checklistCheckedSectionPlan`
  writes `toDone ? 0 : originalIndent`).
- The original position of A1 (child of A) is lost.

When **unchecking A1** afterward:
- A1 goes to the end of the open list, keeping its current indent (0).
- Final document: `A, A2, B, B1, B2, C, D, D1, A1` — A1 is a top-level item
  at the very bottom, no longer a child of A.

Upstream (`origin/main`) sorts order-only (no re-indent), so A1 stays at the
end but still visually indented (level 1). The fork's flatten to 0 is what
breaks the "return home" expectation.

## Goal

When a checked checklist child is unchecked, it returns to its original
parent and position — not to the bottom of the list.

## Non-goals

- No change to cascade toggle (tap = toggle whole block) or frozen-ancestor
  behavior; those stay as in the fork.
- No change to how checking moves a block to the checked section (still
  flattened to 0 on check — only uncheck restores).
- No new DB column. The memory lives in document attributes, so it syncs
  with the note like `checked`/`list` do.
- No server or web changes.

## Approach (P2 — remember parent)

Persist, per checklist line, a hidden "home" attribute on its newline
(alongside `list`/`indent`):

- Attribute name: `anchor-home` (Quill-style key, e.g. `anchor-home`).
- Value: an encoded string `parentId:indent` (or `null` for top-level) where
  `parentId` is a stable line id.

Stable id: Quill newline attributes are per-line and survive edits that do
not delete the line. Use a per-line id attribute `anchor-id` (random short
id generated when a checklist line is created) so `anchor-home` can point
at it. For lines without an id (legacy), fall back to current behavior.

### Lifecycle

1. **Create**: when a checklist line is created (typing `- [ ] `, slash
   menu, split), generate `anchor-id`. No `anchor-home` yet.
2. **Check (move to checked section)**: when a block moves to the checked
   section, for each moved line write `anchor-home = <parentId>:<indent>`
   capturing where it was (its parent's `anchor-id` and its indent at move
   time). Head/children as today.
3. **Uncheck**: instead of appending to the open list at indent 0, read
   `anchor-home`:
   - If the parent id still exists in the same group and that parent is
     unchecked: insert the line **after the parent's last child** (or right
     after the parent if it has no children), restoring its indent.
   - If the parent is gone/checked/not in the group: fall back to current
     behavior (end of open list, keep current indent).
4. **Prune**: when a line's subtree is deleted, drop `anchor-id`/
   `anchor-home` with it (automatic, attributes live on the line).

### Where the code goes

- `document_lines.dart`: parse/expose `homeId`/`homeIndent`/`lineId` on
  `ParsedLine`; helper to build the `anchor-home`/`anchor-id` attribute
  maps.
- `checklist_lines.dart`: `checklistCheckedSectionPlan` gains restore logic
  on uncheck — when `prefer` is a fully-checked block being unchecked,
  compute insertion index from `anchor-home` instead of appending at the
  open-list tail.
- `checklist_sorter.dart` / `rich_text_editor.dart`: on toggle, ensure
  `anchor-id` exists and `anchor-home` is written for moved lines (single
  delta with the toggle+sort, as today).
- `note_blocks.dart`: attribute key constants.

### Edge cases

- Parent checked too: parent leaves the group → child's home is invalid →
  fallback (end of open list).
- Parent deleted: fallback.
- Home points to a line outside the current group (group boundaries moved):
  fallback.
- Legacy lines without `anchor-id`: no memory, fallback.
- Copy/paste of checked lines: `anchor-home` may dangle → fallback.

## Open questions

1. Attribute naming: `anchor-home`/`anchor-id` vs shorter `home`/`id`?
   (Prefixed keys avoid clashing with Quill built-ins and markdown import.)
2. When checking, flatten to 0 as today, or keep original indent and only
   rely on `anchor-home` on uncheck? (Keeping indent on check is a separate
   behavior change; this spec keeps check-as-today.)

## Builder notes

- Tests: extend `checklist_lines` tests with check→uncheck round-trip for
  nested children; add sorter/editor test for the cascade path.
- Attribute payload is tiny (a few bytes per checklist line) and syncs with
  the note; no migration needed.