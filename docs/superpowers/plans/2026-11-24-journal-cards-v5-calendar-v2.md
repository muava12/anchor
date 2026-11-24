# Journal Cards v5 + Calendar Grid v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the Anchor Journal page to the three approved Doop frames: day-grouped entry cards with stats tiles (5b, 5c) and the calendar grid v2 with one card for the selected day.

**Architecture:** Replace the timeline list with a card list built from small shared pieces (card shell, entry card, photo strip, thumbnail stack). Pure functions for dates, leads, tags and stats live beside the existing journal helpers so widgets stay thin. The journal meta parser and the data layer do not change; every entry card stays registered in `CardRegistry` so the note morph still flies from and back to its card.

**Tech Stack:** Flutter, Riverpod, intl, lucide_icons_flutter, `flutter_test` goldens. Run everything from `mobile/` with `rflutter` on box-05.

**Spec:** `docs/superpowers/specs/2026-11-24-journal-cards-v5-calendar-v2-design.md` (frame mapping, token mapping, decisions D1-D10, risks, device checklist). Doop frames: `iQ7khvzQwZ` (5b), `2U-HM5j_dP` (5c), `YesVmaWc4W` (calendar v2), canvas `-IAXF4NORn`.

## Global Constraints

- Only `mobile/` changes. No `server/`, `web/`, DB, sync. `lib/features/journal/domain/journal_meta.dart` (parser) is not edited.
- Conventional Commits `type(mobile): what`. Stage only the files the task touches, never `git add -A`. No AI author or co-author on commits.
- Strings: add to `mobile/lib/l10n/app_en.arb` with `@key.description`, then hand-patch `app_localizations.dart` and `app_localizations_en.dart`. No hard-coded user-facing text.
- Sizes come from the layout scale (4, 8, 12, 16, 24, 32, 48) or `AnchorTokens`; any other number carries `// off-scale: <reason>` on its line or the next. `AnchorTokens.sizeRow|sizeFieldPhone|sizeButtonPhone|sizeControlLarge` need `// same in Compact:`. `test/theme/layout_scale_test.dart` must stay green after every task.
- Card surface: `radiusCard` 16, border `appDivider`, `shadowRaised`, padding `space14`. Thumbnails: `radiusTile` 12, `shadowKnob` + `shadowEdge`.
- Copy and formats: day separator `November 19, 2026 · Thu`; GMT label `GMT+7` and `GMT+5:30`; heat has two levels at alpha 0.14 and 0.28; photo strip is 4 columns, gap 6, height 68, overlay black at 0.45 with `+N`.
- Lead rule (D5): body with no newline and at most 90 characters is short (`typeBody`, clamp 3); anything else uses `typeCardTitle` weight medium, clamp 4.
- Entries inside one day render oldest first (D3), done in the widget; `groupJournalDays` is unchanged.
- Location (D1) is read from `meta.extras['location']` only. Photo `+N` (D4) is `attachmentCount - previews` only when 4 previews exist.
- Checks per task: `cd mobile && dart format lib test && rflutter analyze` plus the task's tests. Goldens are regenerated only on box-05 and reviewed by eye; never in the same commit as a behavior change.

## Review Focus

1. Untitled entry whose body is only whitespace: the card shows time and mood, no empty lead block, no crash. (Task 4)
2. Throwback on a leap day: today is 28 Feb 2027 and an entry exists on 29 Feb 2024; no throwback tile. (Task 1)
3. Long tag name or long location at text scale 1.3 on a 320 dp width: ellipsis, no overflow exception. (Task 4)
4. Entry saved before `tz` existed (`tzOffset == null`): time shows without a GMT suffix. (Task 2)
5. Offline photo (file path null) and an entry with 6 attachments of which only 2 are images: no crash, and `+N` does not appear when fewer than 4 previews exist. (Tasks 2, 5)

---

## PR1: list view cards and stats tiles (frames 5b, 5c)

Branch `feat/journal-cards-v5`.

### Task 1: Stats in the domain layer

**Files:**
- Create: `mobile/lib/features/journal/domain/journal_stats.dart`
- Modify: `mobile/lib/features/journal/presentation/widgets/journal_stats_row.dart` (use the new functions, same three cards for now)
- Test: `mobile/test/journal_stats_test.dart`

**Interfaces:**
- Produces: `int? journalStreakOf(List<JournalDay> days, DateTime now)` (run of consecutive entry days ending today or yesterday; null when shorter than 2).
- Produces: `({int year, int entryCount})? journalThrowbackOf(List<JournalDay> days, DateTime now)` (nearest prior year with entries on today's month and day, and that day's entry count; null when none).

- [ ] **Step 1: Write the failing tests** in `journal_stats_test.dart`:

```dart
test('throwback is the nearest prior year with its entry count', () {
  final days = [
    JournalDay(day: DateTime(2025, 11, 23), entries: [entry('a', DateTime(2025, 11, 23)), entry('b', DateTime(2025, 11, 23))]),
    JournalDay(day: DateTime(2024, 11, 23), entries: [entry('c', DateTime(2024, 11, 23))]),
  ];
  expect(journalThrowbackOf(days, DateTime(2026, 11, 23)), (year: 2025, entryCount: 2));
});

test('a leap-day entry gives no throwback on 28 Feb of a common year', () {
  final days = [JournalDay(day: DateTime(2024, 2, 29), entries: [entry('a', DateTime(2024, 2, 29))])];
  expect(journalThrowbackOf(days, DateTime(2027, 2, 28)), isNull);
});

test('streak needs two days', () {
  final today = DateTime(2026, 11, 23);
  expect(journalStreakOf([JournalDay(day: today, entries: [entry('a', today)])], today), isNull);
});
```

- [ ] **Step 2: Run** `rflutter test test/journal_stats_test.dart`. Expected: FAIL (`journalThrowbackOf` undefined).
- [ ] **Step 3: Implement** both functions in `journal_stats.dart` by moving the streak and throwback logic out of `_Stats.of`; `journal_stats_row.dart` calls them and keeps its three cards and `onThisDay` check (`journalThrowbackOf(...) != null`).
- [ ] **Step 4: Run** `rflutter test test/journal_stats_test.dart`. Expected: PASS, including the pre-existing tests.
- [ ] **Step 5: Commit** `git add mobile/lib/features/journal/domain/journal_stats.dart mobile/lib/features/journal/presentation/widgets/journal_stats_row.dart mobile/test/journal_stats_test.dart && git commit -m 'refactor(mobile): move journal stats into the domain layer'`

### Task 2: Entry text helpers

**Files:**
- Modify: `mobile/lib/features/journal/presentation/journal_entry_text.dart`
- Test: `mobile/test/journal_entry_text_test.dart`

**Interfaces:**
- Produces (all top-level in `journal_entry_text.dart`):
  - `String journalDaySeparator(DateTime day)`
  - `String journalLeadOf(Note note)` (body text, trimmed, no header)
  - `bool isShortLead(String lead)`
  - `String journalTimeLabel(JournalDayEntry entry)` (`clockLabel` plus ` · GMT+7` when `meta.tzOffset != null`; empty when the entry has no time)
  - `String? journalLocationOf(JournalMeta meta)` (trimmed `extras['location']`, null when absent or blank)
  - `List<Tag> journalDisplayTags(Note note, List<Tag> all, String? journalTagId)` (every tag of the note except the journal tag, in `note.tagIds` order)
  - `int journalMoreImages(Note note)` (`attachmentCount - imagePreviewData.length` only when `imagePreviewData.length == maxImagePreviews`, else 0; `maxImagePreviews` is in `notes_repository.dart`)
  - `String gmtLabel(int tzOffsetMinutes)` changes to unpadded hours: `GMT+7`, `GMT-5`, `GMT+5:30`.

- [ ] **Step 1: Write the failing tests**:

```dart
test('day separator', () => expect(journalDaySeparator(DateTime(2026, 11, 19)), 'November 19, 2026 · Thu'));
test('gmtLabel is unpadded', () {
  expect(gmtLabel(420), 'GMT+7');
  expect(gmtLabel(-300), 'GMT-5');
  expect(gmtLabel(330), 'GMT+5:30');
});
test('time label adds GMT only when tz is known', () {
  final at = DateTime(2026, 11, 19, 8, 12);
  expect(journalTimeLabel(JournalDayEntry(note: note, meta: JournalMeta(entryAt: at, tzOffset: 420))), endsWith(' · GMT+7'));
  expect(journalTimeLabel(JournalDayEntry(note: note, meta: JournalMeta(entryAt: at))), clockLabel(at));
});
test('lead is short without newline up to 90 chars', () {
  expect(isShortLead('a' * 90), isTrue);
  expect(isShortLead('a' * 91), isFalse);
  expect(isShortLead('one\ntwo'), isFalse);
});
test('lead of a whitespace-only body is empty', () => expect(journalLeadOf(noteWithBody('  \n ')), ''));
test('location from extras', () {
  expect(journalLocationOf(const JournalMeta(extras: {'location': ' Dago, Bandung '})), 'Dago, Bandung');
  expect(journalLocationOf(const JournalMeta()), isNull);
});
test('more images only when four previews exist', () {
  expect(journalMoreImages(noteWith(previews: 4, attachments: 6)), 2);
  expect(journalMoreImages(noteWith(previews: 2, attachments: 6)), 0);
});
```

Also update the existing assertion that expects `GMT+07` in the day-header test to `GMT+7`.

- [ ] **Step 2: Run** `rflutter test test/journal_entry_text_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the signatures above in `journal_entry_text.dart`. `journalDaySeparator` uses `DateFormat('MMMM d, y', dateLocale)` and `DateFormat('EEE', dateLocale)` joined by ` · `. Tag order follows `note.tagIds`.
- [ ] **Step 4: Run** `rflutter test test/journal_entry_text_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `git add mobile/lib/features/journal/presentation/journal_entry_text.dart mobile/test/journal_entry_text_test.dart && git commit -m 'feat(mobile): add journal card text helpers'`

### Task 3: Today and Throwback tiles

**Files:**
- Modify: `journal_stats_row.dart`, `mobile/lib/l10n/app_en.arb`, `mobile/lib/l10n/app_localizations.dart`, `mobile/lib/l10n/app_localizations_en.dart`
- Test: `mobile/test/journal_stats_test.dart`, `mobile/test/journal_v2_golden_test.dart`, `mobile/test/l10n_test.dart`

**Interfaces:**
- Consumes: `journalStreakOf`, `journalThrowbackOf` (Task 1).
- Produces: `JournalStatsRow({super.key, required List<JournalDay> days})` (same signature). Tiles carry keys `journal-tile-today` and `journal-tile-throwback`. New strings: `journalThrowback` = `Throwback`; `journalStatDays(count)` = `{count, plural, =1{1 day} other{{count} days}}`; `journalStatYearsAgo(count)` = `{count, plural, =1{1 year ago} other{{count} years ago}}`.

- [ ] **Step 1: Write the failing tests** (replace the old three-card tests):

```dart
testWidgets('today tile shows the date and the streak badge', (tester) async {
  await pump(tester, daysWithStreak(3));
  expect(find.byKey(const ValueKey('journal-tile-today')), findsOneWidget);
  expect(find.text('Today'), findsOneWidget);
  expect(find.text('3 days'), findsOneWidget);
});
testWidgets('throwback tile shows count and years ago', (tester) async {
  await pump(tester, daysWithThrowback(yearsAgo: 2, entries: 2));
  expect(find.text('Throwback'), findsOneWidget);
  expect(find.text('2 entries'), findsOneWidget);
  expect(find.text('2 years ago'), findsOneWidget);
});
testWidgets('no throwback hides the tile; no streak hides the badge', (tester) async {
  await pump(tester, todayOnly());
  expect(find.byKey(const ValueKey('journal-tile-throwback')), findsNothing);
  expect(find.textContaining(RegExp(r'\d+ days?$')), findsNothing);
});
```

- [ ] **Step 2: Run** `rflutter test test/journal_stats_test.dart`. Expected: FAIL.
- [ ] **Step 3: Add the three strings** to the ARB (each with `@key.description`) and patch both generated files by hand; extend `l10n_test.dart` for the two plurals.
- [ ] **Step 4: Rewrite `JournalStatsRow`** as two `flex:1` tiles (radius `radius2xl`, border `appBorder`, padding `space12`/`space14`, min height 92 with `// off-scale: design tile height 92`). Tile 1: bookmark icon, optional flame badge, `commonToday`, `DateFormat('EEE, MMM d', dateLocale)`. Tile 2 only when `journalThrowbackOf` is non-null. Remove the `onThisDay` card (its ARB key goes in Task 7).
- [ ] **Step 5: Run** `rflutter test test/journal_stats_test.dart test/l10n_test.dart test/theme/layout_scale_test.dart`. Expected: PASS.
- [ ] **Step 6: Regenerate and inspect** `rflutter test test/journal_v2_golden_test.dart --update-goldens --plain-name 'journal stats row'`; open `goldens/journal_stats_row.png` and compare with frame 5b tiles.
- [ ] **Step 7: Commit** the touched files: `git commit -m 'feat(mobile): show today and throwback tiles on the journal'`

### Task 4: Card shell, entry card, day card

**Files:**
- Create: `widgets/journal_card_shell.dart`, `widgets/journal_entry_card.dart`, `widgets/journal_day_card.dart` (all under `mobile/lib/features/journal/presentation/`)
- Test: `mobile/test/journal_entry_card_test.dart`, `mobile/test/journal_day_card_test.dart`

**Interfaces:**
- Consumes: Task 2 helpers; `MoodFace`, `TagChip`, `Pressable`, `CardRegistry`.
- Produces:
  - `JournalCardShell({super.key, required List<Widget> children})`: surface per Global Constraints; inserts a 1 px divider (key `journal-card-divider`, horizontal margin `space14`) between children.
  - `JournalRegisteredEntry({super.key, required String noteId, required String semanticLabel, required VoidCallback onTap, required Widget child})`: `Pressable(PressStyle.plain)` around `ValueListenableBuilder<Set<String>>(CardRegistry.hidden)` + `Opacity` around `RepaintBoundary(key: CardRegistry.keyFor(noteId))`.
  - `JournalEntryCard({super.key, required JournalDayEntry entry, required List<Tag> tags})`: padding `space14`. Titled: time label, title (clamp 2), mood 28 on the right, snippet (clamp 2). Untitled: header row (time left, mood right, min height 28), lead per the lead rule. Footer wrap (gap `space8`, hidden when empty): location chip (pin icon plus ellipsized text, `Semantics` label from new `journalLocationLabel(place)` = `Location: {place}`), then one `TagChip` per tag. A photo slot is added in Task 5.
  - `JournalDayCard({super.key, required JournalDay day, required List<Tag> tags, required String? journalTagId, required ValueChanged<Note> onOpen})`: entries oldest first. One entry: `JournalRegisteredEntry` wraps the whole `JournalCardShell`. Several: one `JournalRegisteredEntry` per entry inside the shell.

- [ ] **Step 1: Write the failing tests** in `journal_entry_card_test.dart`:

```dart
testWidgets('titled card shows time, title, snippet and mood', (tester) async {
  await pumpCard(tester, titled(title: 'Morning pages', body: 'Coffee on the balcony.', mood: JournalMood.calm));
  expect(find.text('Morning pages'), findsOneWidget);
  expect(find.text('Coffee on the balcony.'), findsOneWidget);
  expect(find.byType(MoodFace), findsOneWidget);
});
testWidgets('untitled short lead uses the body size, long uses the card-title size', (tester) async {
  await pumpCard(tester, untitled(body: 'Slow start.'));
  expect(tester.widget<Text>(find.text('Slow start.')).style!.fontSize, AnchorTokens.typeBody.fontSize);
  await pumpCard(tester, untitled(body: 'x ' * 80));
  expect(tester.widget<Text>(find.byKey(const ValueKey('journal-lead'))).style!.fontSize, AnchorTokens.typeCardTitle.fontSize);
});
testWidgets('whitespace-only untitled body draws no lead and does not throw', (tester) async {
  await pumpCard(tester, untitled(body: '  \n '));
  expect(find.byKey(const ValueKey('journal-lead')), findsNothing);
  expect(tester.takeException(), isNull);
});
testWidgets('footer lists location and every tag, and is hidden when empty', (tester) async {
  await pumpCard(tester, titled(extras: {'location': 'Dago, Bandung'}), tags: [tagA, tagB]);
  expect(find.text('Dago, Bandung'), findsOneWidget);
  expect(find.byType(TagChip), findsNWidgets(2));
  await pumpCard(tester, titled());
  expect(find.byType(TagChip), findsNothing);
  expect(find.byKey(const ValueKey('journal-card-footer')), findsNothing);
});
testWidgets('long tag and location ellipsize at text scale 1.3 on 320 dp', (tester) async {
  await pumpCard(tester, titled(extras: {'location': 'L' * 120}), tags: [Tag(id: 'x', name: 'T' * 80)], width: 320, textScale: 1.3);
  expect(tester.takeException(), isNull);
});
```

and in `journal_day_card_test.dart`:

```dart
testWidgets('two entries: one shell, one divider, oldest first, each registered', (tester) async {
  await pumpDay(tester, dayWith(['late', DateTime(2026,11,15,17,40)], ['early', DateTime(2026,11,15,8,30)]));
  expect(find.byType(JournalCardShell), findsOneWidget);
  expect(find.byKey(const ValueKey('journal-card-divider')), findsOneWidget);
  expect(tester.getTopLeft(find.text('early')).dy, lessThan(tester.getTopLeft(find.text('late')).dy));
  expect(CardRegistry.keyFor('early').currentContext, isNotNull);
  expect(CardRegistry.keyFor('late').currentContext, isNotNull);
});
testWidgets('single entry: the registered boundary wraps the whole card', (tester) async {
  await pumpDay(tester, dayWith(['only', DateTime(2026,11,19,8,12)]));
  expect(find.descendant(of: find.byKey(CardRegistry.keyFor('only')), matching: find.byType(JournalCardShell)), findsOneWidget);
});
testWidgets('hiding one entry hides only that entry', (tester) async {
  await pumpDay(tester, dayWith(['a', t1], ['b', t2]));
  CardRegistry.hide('a'); await tester.pump();
  expect(opacityOf(tester, 'a'), 0); expect(opacityOf(tester, 'b'), 1);
  CardRegistry.show('a');
});
testWidgets('tapping an entry opens that note', (tester) async { /* onOpen receives the tapped Note */ });
```

- [ ] **Step 2: Run** `rflutter test test/journal_entry_card_test.dart test/journal_day_card_test.dart`. Expected: FAIL (files missing).
- [ ] **Step 3: Add `journalLocationLabel`** to the ARB (with description) and hand-patch both generated l10n files.
- [ ] **Step 4: Implement** the four widgets with the signatures above. The lead `Text` carries key `journal-lead`; the footer carries key `journal-card-footer` and is omitted when it has no children. Semantic label stays `'$title · $time'` (title falls back to `journalTitleOf`).
- [ ] **Step 5: Run** the two test files plus `test/theme/layout_scale_test.dart`. Expected: PASS.
- [ ] **Step 6: Commit** `git commit -m 'feat(mobile): render journal entries as cards'` (staging the three widgets, two tests, ARB and generated l10n).

### Task 5: Photo strip

**Files:**
- Create: `widgets/journal_photo_strip.dart`
- Modify: `widgets/journal_entry_card.dart` (insert the strip between snippet/lead and footer)
- Test: `mobile/test/journal_photo_strip_test.dart`; l10n key `journalPhotosMore(count)` = `+{count}` in ARB and both generated files.

**Interfaces:**
- Consumes: `attachmentFileProvider`, `previewFileKeyOf`, `journalMoreImages`.
- Produces: `JournalPhotoStrip({super.key, required List<NoteImagePreview> previews, int more = 0})`: grid of 4 equal columns, gap `space6`, cell height 68 (`// off-scale: design strip height 68`), cells keyed `journal-photo-0`..`3`; shown by `JournalEntryCard` only when `previews` is non-empty, with `more: journalMoreImages(note)`.

- [ ] **Step 1: Write the failing tests**:

```dart
testWidgets('one photo keeps the 4-column cell width', (tester) async {
  final one = await widthOfCell(tester, previews: 1);
  final four = await widthOfCell(tester, previews: 4);
  expect(one, four);
});
testWidgets('+N overlay only on the 4th cell', (tester) async {
  await pumpStrip(tester, previews: 4, more: 2);
  expect(find.text('+2'), findsOneWidget);
  expect(find.descendant(of: find.byKey(const ValueKey('journal-photo-3')), matching: find.text('+2')), findsOneWidget);
  await pumpStrip(tester, previews: 4, more: 0);
  expect(find.textContaining('+'), findsNothing);
});
testWidgets('an unresolved file path (offline) does not throw', (tester) async {
  await pumpStrip(tester, previews: 3, filePath: null);
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run** `rflutter test test/journal_photo_strip_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** `JournalPhotoStrip`: reuse the image loading and missing-file placeholder from `_EntryThumbnails` in `journal_timeline.dart` (`Image.file`, `cacheWidth` as there, `errorBuilder`), cell radius `radiusTile`, shadows `shadowKnob` + `shadowEdge`, overlay `Colors.black.withValues(alpha: 0.45)` with `// off-scale: design overlay alpha` and `typeUi` bold white `+N`.
- [ ] **Step 4: Run** `rflutter test test/journal_photo_strip_test.dart test/journal_entry_card_test.dart test/l10n_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m 'feat(mobile): add the photo strip to journal cards'`

### Task 6: Card list on the Journal screen

**Files:**
- Create: `widgets/journal_cards_list.dart`, `widgets/journal_section_header.dart`
- Modify: `mobile/lib/features/journal/presentation/journal_screen.dart`, ARB + generated l10n (`journalEntriesSection` = `Entries`, plus `journalEntriesOptions` = `Entry options` for the inert icon, D9)
- Test: `mobile/test/journal_screen_test.dart`, `mobile/test/journal_v2_golden_test.dart`

**Interfaces:**
- Consumes: `JournalDayCard`, `journalDaySeparator`, `journalDisplayTags`, `tagsControllerProvider`.
- Produces: `JournalCardsList({super.key, required List<JournalDay> days, required String? journalTagId, required ValueChanged<Note> onOpen})` as a sliver: per day a centered separator (`typeMeta` medium, muted, padding `space16`/0/`space8`) then `JournalDayCard`, horizontal margin 16. `JournalSectionHeader({super.key})`: `ENTRIES` label plus a 20 px lines icon with `onPressed: null`.

- [ ] **Step 1: Write the failing tests** in `journal_screen_test.dart`:

```dart
testWidgets('list mode shows the section header, day separator and card', (tester) async {
  await pump(tester, [entry('a', 'Morning pages', 'good')]);
  expect(find.text('ENTRIES'), findsOneWidget);
  expect(find.text('November 17, 2026 · Tue'), findsOneWidget);
  expect(find.byType(JournalCardShell), findsOneWidget);
  expect(find.byType(JournalTimeline), findsNothing);
});
testWidgets('search filters cards but the tiles keep the full-history numbers', (tester) async { /* type a query that matches one entry; tile text unchanged */ });
```

Keep the existing chevron, compact-bottom-bar and calendar tests unchanged.

- [ ] **Step 2: Run** `rflutter test test/journal_screen_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the list and header, then in `journal_screen.dart` swap `JournalTimeline` for `JournalCardsList` in list mode, with `JournalSectionHeader` after the stats row. The calendar branch is untouched in this task.
- [ ] **Step 4: Add a golden** `journal cards list` (titled + untitled + multi-entry day) to `journal_v2_golden_test.dart`; regenerate on box-05 with `--update-goldens --plain-name 'journal cards list'` and inspect against frames 5b and 5c.
- [ ] **Step 5: Run** `rflutter analyze && rflutter test`. Expected: PASS (full suite; `journal_day_cards_test` and `journal_timeline_test` still pass because those widgets are unchanged).
- [ ] **Step 6: Device pass** on the spec checklist §8.2 (list, tiles, location fixture with a `location:` header, morph from a single card and from the second entry of a multi card, search, scroll, light and dark). Attach before/after screenshots.
- [ ] **Step 7: Commit** `git commit -m 'feat(mobile): switch the journal list to cards'`, then open PR1.

---

## PR2: calendar grid v2

Branch `feat/journal-calendar-v2` from `main` after PR1 merges.

### Task 7: Thumbnail stack extraction and timeline removal

**Files:**
- Create: `widgets/journal_thumb_stack.dart`, `mobile/test/journal_thumb_stack_test.dart`
- Delete: `widgets/journal_timeline.dart`, `mobile/test/journal_timeline_test.dart`, `mobile/test/goldens/journal_timeline.png`, the timeline golden test
- Modify: `journal_entry_text.dart` (remove the unused `journalDayHeader` and `_dayTz`, with their tests), ARB + generated l10n (remove `journalStatOnThisDay`, `journalStatStreak`, `journalStatThrowback` once no code references them)

**Interfaces:**
- Produces: `JournalThumbStack({super.key, required List<NoteImagePreview> previews})`: the stack code of `_EntryThumbnails`, moved as is (1 to 3 previews).

- [ ] **Step 1: Move the stack tests** from `journal_timeline_test.dart` into `journal_thumb_stack_test.dart` against `JournalThumbStack`. Run `rflutter test test/journal_thumb_stack_test.dart`. Expected: FAIL (widget missing).
- [ ] **Step 2: Extract** `_EntryThumbnails` into `JournalThumbStack` unchanged.
- [ ] **Step 3: Delete** the timeline files listed above and grep `lib/` and `test/` for leftover references (`JournalTimeline`, `journalDayHeader`, removed l10n keys); fix them.
- [ ] **Step 4: Run** `rflutter analyze && rflutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m 'refactor(mobile): extract the journal thumbnail stack and drop the timeline'`

### Task 8: Calendar grid visuals and two-level heat

**Files:**
- Modify: `mobile/lib/features/journal/domain/journal_day.dart` (`heatLevelOf`), `widgets/journal_calendar.dart`
- Test: `mobile/test/journal_day_test.dart`, `mobile/test/journal_calendar_test.dart`

**Interfaces:**
- Produces: `int heatLevelOf(int count)` returns 0 for 0, 1 for 1, 2 for 2 or more. `JournalCalendar` keeps its constructor. Keys added: `calendar-month` (the month `Text.rich`), `journal-heat-0`, `journal-heat-1`, `journal-heat-2` (legend swatches), `calendar-today-ring`.

- [ ] **Step 1: Write the failing tests**:

```dart
test('heat has two levels', () {
  expect([0, 1, 2, 3, 9].map(heatLevelOf), [0, 1, 2, 2, 2]);
});
testWidgets('month title is the month plus a small year', (tester) async {
  await pumpCalendar(tester);
  final text = tester.widget<Text>(find.byKey(const ValueKey('calendar-month')));
  expect(text.textSpan!.toPlainText(), contains('November'));
  expect(text.textSpan!.toPlainText(), contains('2026'));
});
testWidgets('day cells are square', (tester) async {
  await pumpCalendar(tester);
  final size = tester.getSize(find.byKey(const ValueKey('calendar-day-2026-11-05')));
  expect(size.width, size.height);
});
testWidgets('today keeps its ring when it has entries and is not selected', (tester) async {
  await pumpCalendar(tester, today: DateTime(2026, 11, 5), counts: {DateTime(2026, 11, 5): 1}, selected: DateTime(2026, 11, 17));
  expect(find.byKey(const ValueKey('calendar-today-ring')), findsOneWidget);
});
testWidgets('legend has zero, one and two swatches between Less and More', (tester) async {
  await pumpCalendar(tester);
  for (final i in [0, 1, 2]) { expect(find.byKey(ValueKey('journal-heat-$i')), findsOneWidget); }
});
```

Update the old assertion `find.text('November 2026')` and the 4-entry heat expectations in `journal_calendar_test.dart`.

> **Ruling (journal-v5 execution):** to keep the today-ring test deterministic, `JournalCalendar` gains one optional `DateTime? now` parameter (defaults to `DateTime.now()`); "today" is computed from it. The constructor otherwise keeps its shape. `pumpCalendar` passes `now: today`.

- [ ] **Step 2: Run** `rflutter test test/journal_day_test.dart test/journal_calendar_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** `heatLevelOf`, then restyle `journal_calendar.dart` per the spec F3 table: card radius `radius3xl` with `shadowRaised`; nav buttons `sizeControlSmall` with a 7% text tint; month in `typeHeading` plus a muted `typeLabel` year; weekday labels caption semibold; cells `childAspectRatio: 1`, radius `radiusXl`, gaps `space4` rows and 3 columns (`// off-scale: design column gap 3`); heat alpha `[0, 0.14, 0.28]`; ring on any non-selected today; selected cell with `shadowControl`; out-of-month cells opacity 0.4; legend swatch row of three keyed swatches (12 px, radius 4, `// off-scale: heat swatch`).
- [ ] **Step 4: Run** the two test files plus `test/theme/layout_scale_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m 'feat(mobile): restyle the journal calendar grid'`

### Task 9: Selected day as one card with a thumbnail stack

**Files:**
- Modify: `widgets/journal_day_cards.dart` (rewrite), `widgets/journal_thumb_stack.dart` (geometry to the frame)
- Test: `mobile/test/journal_day_cards_test.dart`, `mobile/test/journal_thumb_stack_test.dart`, `mobile/test/journal_v2_golden_test.dart`

**Interfaces:**
- Consumes: `JournalCardShell`, `JournalRegisteredEntry`, `JournalThumbStack`, `journalDisplayTags`, `journalLeadOf`, `MoodFace`.
- Produces: `JournalDayCards({super.key, required List<JournalDay> days, required String? journalTagId, required ValueChanged<Note> onOpen})` (same signature). Day header `EEE, d MMM` uppercase, `TODAY` pill at accent alpha 0.20, `journalEntriesCount` on the right. One `JournalCardShell` per day; each entry is a `JournalRegisteredEntry` with a row: left column (titled: title plus snippet clamp 2; untitled: lead clamp 4) and the meta row (time via `clockLabel` without GMT, dot, `MoodFace` 20, one `TagChip` per tag); right a 56 px `JournalThumbStack` only when the note has image previews. Stack geometry from the frame: back layers 42 px at 9 deg and opacity 0.7 (top right), middle 44 px at 4 deg and 0.9, front 46 px bottom left, each number with an `// off-scale:` comment.

- [ ] **Step 1: Update the failing tests** in `journal_day_cards_test.dart`:

```dart
testWidgets('header and one shell with a divider between two entries', (tester) async {
  await pumpDay(tester, twoEntriesOn(DateTime(2026, 11, 17)));
  expect(find.text('TUE, 17 NOV'), findsOneWidget);
  expect(find.text('2 entries'), findsOneWidget);
  expect(find.byType(JournalCardShell), findsOneWidget);
  expect(find.byKey(const ValueKey('journal-card-divider')), findsOneWidget);
});
testWidgets('stack only for entries with pictures', (tester) async {
  await pumpDay(tester, dayWithPictures(1) + dayWithoutPictures());
  expect(find.byType(JournalThumbStack), findsOneWidget);
});
testWidgets('untitled entry shows its lead and no title line', (tester) async { /* find.byKey('journal-lead') one, no bold title Text */ });
testWidgets('meta lists time, mood and every tag', (tester) async { /* TagChip count == tags minus journal */ });
```

Keep the CardRegistry tests from Task 4 pattern (per-entry key, hide one entry).

- [ ] **Step 2: Run** `rflutter test test/journal_day_cards_test.dart`. Expected: FAIL.
- [ ] **Step 3: Rewrite** `journal_day_cards.dart` per the Interfaces block and adjust the stack geometry; add stack tests for 1, 2 and 3 previews to `journal_thumb_stack_test.dart` (rotation present only on the back layers).
- [ ] **Step 4: Run** `rflutter test test/journal_day_cards_test.dart test/journal_thumb_stack_test.dart test/theme/layout_scale_test.dart`. Expected: PASS.
- [ ] **Step 5: Regenerate goldens** `journal_day_cards.png` on box-05 (`--update-goldens --plain-name 'journal day cards'`), inspect against frame `YesVmaWc4W`.
- [ ] **Step 6: Commit** `git commit -m 'feat(mobile): show the selected day as one card with a thumbnail stack'`

### Task 10: Calendar toolbar button

**Files:**
- Modify: `mobile/lib/features/journal/presentation/journal_screen.dart`
- Test: `mobile/test/journal_screen_test.dart`

**Interfaces:**
- Consumes: existing `BarButton(icon, label, isOn, onPressed)`. The icon stays `LucideIcons.calendarDays` in both modes; `isOn` is true in calendar mode; the label keeps naming the action (`journalTimeline` while on, `journalCalendar` while off).

- [ ] **Step 1: Write the failing test**:

```dart
testWidgets('the calendar icon stays while the calendar is on', (tester) async {
  await pump(tester, [entry('a', 'Morning pages', 'good')]);
  await tester.tap(find.byIcon(LucideIcons.calendarDays));
  await tester.pumpAndSettle();
  expect(find.byType(JournalCalendar), findsOneWidget);
  expect(find.byIcon(LucideIcons.calendarDays), findsOneWidget);
  expect(find.byIcon(LucideIcons.rows3), findsNothing);
  await tester.tap(find.byIcon(LucideIcons.calendarDays));
  await tester.pumpAndSettle();
  expect(find.byType(JournalCalendar), findsNothing);
});
```

- [ ] **Step 2: Run** `rflutter test test/journal_screen_test.dart`. Expected: FAIL (icon swaps to `rows3`).
- [ ] **Step 3: Change** the `icon:` argument to always `LucideIcons.calendarDays`.
- [ ] **Step 4: Run** `rflutter analyze && rflutter test`. Expected: PASS.
- [ ] **Step 5: Device pass** on spec §8.2 calendar items (month change, empty / one / many entries, today with and without selection, morph from the calendar card, chevron and `TagChip` parity with the frame, light and dark). Attach before/after screenshots.
- [ ] **Step 6: Commit** `git commit -m 'feat(mobile): keep the calendar icon while the calendar is on'`, then open PR2.

---

## PR3: visual polish

Branch `chore/journal-cards-polish` from `main` after PR2 merges.

### Task 11: Dark goldens and verification fixes

**Files:**
- Modify: `mobile/test/journal_v2_golden_test.dart`; new PNGs under `mobile/test/goldens/`

**Interfaces:**
- Consumes: the dark counterpart of `AppTheme.light()` (confirm the name in `lib/core/theme/app_theme.dart`).
- Produces: dark variants of the cards list, stats row and day cards goldens.

- [ ] **Step 1: Add dark goldens** by parameterising `_pumpPhone` over the theme; first run fails because the PNGs do not exist: `rflutter test test/journal_v2_golden_test.dart`. Expected: FAIL.
- [ ] **Step 2: Generate and inspect** with `--update-goldens`; compare each PNG with the dark frames (frames are dark-themed).
- [ ] **Step 3: Run** `rflutter test`. Expected: PASS.
- [ ] **Step 4: Commit** `git commit -m 'test(mobile): add dark journal goldens'`
- [ ] **Step 5: Fix what the device pass found**, one `fix(mobile): ...` commit per problem, each with its own failing test first: lead threshold if the owner corrects D5, `TagChip` colour parity, morph radius on multi-entry cards, text scale 1.3 overflow. Re-run the Review Focus tests after each fix.
- [ ] **Step 6: Final check** `cd mobile && dart format lib test && rflutter analyze && rflutter test`; Expected: no format diff, no analyzer issues, all tests pass. Open PR3.

## Rulings recorded during execution (journal-v5 worktree)

- **Divider keys (Task 4):** `JournalCardShell` keys each divider `ValueKey('journal-card-divider-$i')` (i = child index), not one shared `journal-card-divider` key: a day with 3+ entries would otherwise register duplicate sibling keys (debug assertion). Tests updated to `journal-card-divider-1` (+ a new 3-entry test).
- **Untitled header (Task 4, F2):** header is a `minHeight: 28` container (key `journal-untitled-header`) with the row centred, not a fixed 28 `SizedBox` (spec §7: safe at text scale 1.3).
- **`JournalCalendar` `now` param (Task 8):** optional `DateTime? now` for deterministic today-ring tests (defaults to `DateTime.now()`).
- **l10n files:** bulk `dart format` on box-05 re-wrapped two unrelated strings in `app_localizations_en.dart`; restored to base formatting so the feat commits carry only the journal keys.
- **Commit author:** this host's git identity is `openhands <openhands@all-hands.dev>`; AGENTS.md forbids an AI author. Left as-is (identity is host-wide, not branch-wide); the owner picks the author when pushing. Name the tool in the PR body instead.
