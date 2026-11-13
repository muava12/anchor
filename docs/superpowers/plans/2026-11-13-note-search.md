# Search inside a note — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A search button in the note's top bar opens a field that highlights every match in the open note, counts them, and steps between them with two arrows.

**Architecture:** `findMatches` is a pure function over the document's plain text. `NoteSearchController` holds the query, the ranges and the active index, and notifies. The existing `HighlightUnderlay` painter draws the ranges, so the document is never edited. The note screen swaps `NoteBar` for `NoteSearchBar` while a search is open.

**Tech Stack:** Flutter 3.47.9, flutter_quill, Riverpod, flutter_test.

## Global Constraints

- Flutter 3.47.9; `flutter analyze` must report no issues, warnings included.
- User-facing copy is English, in `lib/l10n/app_en.arb`, with the generated files edited by hand and committed.
- The document is never modified by a search: no attribute is written, so the note stays clean and nothing syncs.
- The editor's selection and focus do not change while searching.
- At most 500 matches are kept.
- Verify with `flutter analyze` and `flutter test` on box-03 (`/data/workspace/toolchain/flutter/bin/flutter`).

---

### Task 1: Finding the matches

**Files:**
- Create: `mobile/lib/features/notes/presentation/editor/note_search.dart`
- Test: `mobile/test/note_search_test.dart`

**Interfaces:**
- Produces: `class NoteSearch` with `query`, `matches` (`List<TextRange>`), `active` (`int`), `const NoteSearch.empty()`, `copyWith`, and `List<TextRange> findMatches(String text, String query)`; `const int maxSearchMatches = 500`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:anchor/features/notes/presentation/editor/note_search.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds every occurrence whatever the case', () {
    final ranges = findMatches('Tram 28 and the tram stop', 'tram');
    expect(ranges, const [
      TextRange(start: 0, end: 4),
      TextRange(start: 13, end: 17),
    ]);
  });

  test('matches do not overlap', () {
    expect(findMatches('aaaa', 'aa'), const [
      TextRange(start: 0, end: 2),
      TextRange(start: 2, end: 4),
    ]);
  });

  test('an empty or blank query finds nothing', () {
    expect(findMatches('anything', ''), isEmpty);
    expect(findMatches('anything', '   '), isEmpty);
  });

  test('a query with no hit finds nothing', () {
    expect(findMatches('anything', 'zebra'), isEmpty);
  });

  test('stops at the cap', () {
    final ranges = findMatches('a' * 1200, 'a');
    expect(ranges, hasLength(maxSearchMatches));
  });

  test('the empty search has no matches and no active index', () {
    const search = NoteSearch.empty();
    expect(search.query, isEmpty);
    expect(search.matches, isEmpty);
    expect(search.active, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/note_search_test.dart`
Expected: FAIL — the file does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/services.dart';

/// How many matches a search keeps. Past this the counter says "500+".
const int maxSearchMatches = 500;

/// The ranges of [query] in [text], whatever the case, never overlapping.
List<TextRange> findMatches(String text, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  final haystack = text.toLowerCase();
  final ranges = <TextRange>[];
  var from = 0;
  while (ranges.length < maxSearchMatches) {
    final at = haystack.indexOf(needle, from);
    if (at < 0) break;
    ranges.add(TextRange(start: at, end: at + needle.length));
    from = at + needle.length;
  }
  return ranges;
}

/// What the note screen searches for, and where it is.
@immutable
class NoteSearch {
  const NoteSearch({
    this.query = '',
    this.matches = const [],
    this.active = 0,
  });

  const NoteSearch.empty() : this();

  final String query;
  final List<TextRange> matches;

  /// Which match the arrows are on. Always inside [matches] when it is not
  /// empty.
  final int active;

  bool get isEmpty => query.trim().isEmpty;

  bool get hasMatches => matches.isNotEmpty;

  /// The match the page scrolls to, or null.
  TextRange? get activeRange =>
      hasMatches ? matches[active.clamp(0, matches.length - 1)] : null;

  NoteSearch copyWith({String? query, List<TextRange>? matches, int? active}) =>
      NoteSearch(
        query: query ?? this.query,
        matches: matches ?? this.matches,
        active: active ?? this.active,
      );
}
```

Add `import 'package:flutter/foundation.dart';` for `@immutable`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/note_search_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/notes/presentation/editor/note_search.dart mobile/test/note_search_test.dart
git commit -m "feat(mobile): find the matches of a search inside a note"
```

---

### Task 2: The controller that holds the search

**Files:**
- Create: `mobile/lib/features/notes/presentation/editor/note_search_controller.dart`
- Test: `mobile/test/note_search_test.dart`

**Interfaces:**
- Consumes: `NoteSearch`, `findMatches` from Task 1.
- Produces: `class NoteSearchController extends ChangeNotifier` with `NoteSearch get search`, `void setQuery(String)`, `void next()`, `void previous()`, `void clear()`, `void refresh(String text)`, and a constructor `NoteSearchController({String Function()? textOf, Duration debounce = const Duration(milliseconds: 150)})`.

- [ ] **Step 1: Write the failing test**

Append to `mobile/test/note_search_test.dart`:

```dart
  test('typing finds matches and starts at the first', () async {
    final controller = NoteSearchController(
      textOf: () => 'tram tram tram',
      debounce: Duration.zero,
    );
    addTearDown(controller.dispose);

    controller.setQuery('tram');
    await Future<void>.delayed(Duration.zero);

    expect(controller.search.matches, hasLength(3));
    expect(controller.search.active, 0);
  });

  test('the arrows wrap around', () async {
    final controller = NoteSearchController(
      textOf: () => 'tram tram',
      debounce: Duration.zero,
    );
    addTearDown(controller.dispose);
    controller.setQuery('tram');
    await Future<void>.delayed(Duration.zero);

    controller.next();
    expect(controller.search.active, 1);
    controller.next();
    expect(controller.search.active, 0);
    controller.previous();
    expect(controller.search.active, 1);
  });

  test('clearing empties the query and the matches', () async {
    final controller = NoteSearchController(
      textOf: () => 'tram',
      debounce: Duration.zero,
    );
    addTearDown(controller.dispose);
    controller.setQuery('tram');
    await Future<void>.delayed(Duration.zero);

    controller.clear();

    expect(controller.search.query, isEmpty);
    expect(controller.search.matches, isEmpty);
  });

  test('a document change keeps the active match inside the new list', () async {
    var text = 'tram tram tram';
    final controller = NoteSearchController(
      textOf: () => text,
      debounce: Duration.zero,
    );
    addTearDown(controller.dispose);
    controller.setQuery('tram');
    await Future<void>.delayed(Duration.zero);
    controller.next();
    controller.next();
    expect(controller.search.active, 2);

    text = 'tram';
    controller.refresh(text);

    expect(controller.search.matches, hasLength(1));
    expect(controller.search.active, 0);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/note_search_test.dart`
Expected: FAIL — `NoteSearchController` is not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'note_search.dart';

/// Holds what the note screen is searching for.
///
/// The text comes from [textOf], so the controller never touches the editor
/// itself and stays testable without one.
class NoteSearchController extends ChangeNotifier {
  NoteSearchController({
    String Function()? textOf,
    this.debounce = const Duration(milliseconds: 150),
  }) : _textOf = textOf ?? (() => '');

  final String Function() _textOf;
  final Duration debounce;

  NoteSearch _search = const NoteSearch.empty();
  Timer? _timer;

  NoteSearch get search => _search;

  void setQuery(String query) {
    _search = _search.copyWith(query: query);
    notifyListeners();
    _timer?.cancel();
    if (debounce == Duration.zero) {
      _recompute();
      return;
    }
    _timer = Timer(debounce, _recompute);
  }

  /// Recomputes against [text], keeping the active match inside the new list.
  void refresh(String text) {
    final matches = findMatches(text, _search.query);
    _search = _search.copyWith(
      matches: matches,
      active: matches.isEmpty ? 0 : _search.active.clamp(0, matches.length - 1),
    );
    notifyListeners();
  }

  void next() => _step(1);

  void previous() => _step(-1);

  void clear() {
    _timer?.cancel();
    _search = const NoteSearch.empty();
    notifyListeners();
  }

  void _step(int by) {
    final count = _search.matches.length;
    if (count == 0) return;
    _search = _search.copyWith(active: (_search.active + by + count) % count);
    notifyListeners();
  }

  void _recompute() => refresh(_textOf());

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/note_search_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/notes/presentation/editor/note_search_controller.dart mobile/test/note_search_test.dart
git commit -m "feat(mobile): hold the note search in a controller"
```

---

### Task 3: Paint the matches under the text

**Files:**
- Modify: `mobile/lib/features/notes/presentation/editor/highlight_underlay.dart`
- Modify: `mobile/lib/features/notes/presentation/editor/rich_text_editor.dart`
- Modify: `mobile/lib/core/theme/tokens/anchor_tokens.dart`
- Test: `mobile/test/widgets/note_search_test.dart`

**Interfaces:**
- Consumes: `NoteSearch` from Task 1.
- Produces: `HighlightUnderlay({... required NoteSearch search, required Color searchFill, required Color searchActiveFill})`; `RichTextEditor({... NoteSearch search = const NoteSearch.empty()})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/presentation/editor/note_search.dart';
import 'package:anchor/features/notes/presentation/editor/rich_text_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the editor paints a search without touching the document', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RichTextEditor(
            initialContent: '{"ops":[{"insert":"tram 28\\n"}]}',
            search: const NoteSearch(
              query: 'tram',
              matches: [TextRange(start: 0, end: 4)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/widgets/note_search_test.dart`
Expected: FAIL — `RichTextEditor` has no `search` parameter.

- [ ] **Step 3: Write minimal implementation**

`mobile/lib/core/theme/tokens/anchor_tokens.dart`, beside the other colours:

```dart
  /// Behind a search match in a note.
  static const Color searchHighlight = Color(0x33FFD54F);

  /// Behind the match the arrows are on.
  static const Color searchHighlightActive = Color(0x99FFB300);
```

`mobile/lib/features/notes/presentation/editor/highlight_underlay.dart`:

- Add the fields and constructor parameters:

```dart
    required this.search,
    required this.searchFill,
    required this.searchActiveFill,
```

```dart
  final NoteSearch search;
  final Color searchFill;
  final Color searchActiveFill;
```

- In `_paintNode`, after the existing highlight loop for a `Line`, paint the search ranges that fall inside this line:

```dart
    _paintSearch(canvas, render, host, start, start + node.length);
```

- Add the method:

```dart
  /// Paints the search matches that fall inside [from]..[to].
  void _paintSearch(
    Canvas canvas,
    RenderEditor render,
    RenderBox host,
    int from,
    int to,
  ) {
    if (!search.hasMatches) return;
    final active = search.activeRange;
    for (final range in search.matches) {
      if (range.end <= from || range.start >= to) continue;
      final start = range.start.clamp(from, to);
      final end = range.end.clamp(from, to);
      if (end <= start) continue;
      final isActive = active != null &&
          active.start == range.start &&
          active.end == range.end;
      _paintSearchRange(
        canvas,
        render,
        host,
        start,
        end,
        isActive ? searchActiveFill : searchFill,
      );
    }
  }

  void _paintSearchRange(
    Canvas canvas,
    RenderEditor render,
    RenderBox host,
    int start,
    int end,
    Color color,
  ) {
    var position = start;
    var guard = 0;
    while (position < end && guard++ < 200) {
      final line = render.getLineAtOffset(TextPosition(offset: position));
      final segmentEnd = line.end.clamp(position, end);
      if (segmentEnd <= position) break;
      final startRect = render.getLocalRectForCaret(
        TextPosition(offset: position),
      );
      final endRect = render.getLocalRectForCaret(
        TextPosition(offset: segmentEnd, affinity: TextAffinity.upstream),
      );
      final topLeft = host.globalToLocal(
        render.localToGlobal(startRect.topLeft),
      );
      final right = host
          .globalToLocal(
            render.localToGlobal(Offset(endRect.left, startRect.top)),
          )
          .dx;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            topLeft.dx,
            topLeft.dy,
            right - topLeft.dx,
            startRect.height,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = color,
      );
      position = segmentEnd;
    }
  }
```

Add the import:

```dart
import 'note_search.dart';
```

`mobile/lib/features/notes/presentation/editor/rich_text_editor.dart`:

- Add the widget field and constructor parameter:

```dart
    this.search = const NoteSearch.empty(),
```

```dart
  /// What the note screen is searching for. Painted, never written.
  final NoteSearch search;
```

- Pass it to the painter at the `HighlightUnderlay(` call site:

```dart
                  search: widget.search,
                  searchFill: AnchorTokens.searchHighlight,
                  searchActiveFill: AnchorTokens.searchHighlightActive,
```

- Add the import:

```dart
import 'note_search.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/widgets/note_search_test.dart && flutter analyze`
Expected: PASS, 1 test; analyze reports no issues.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/theme/tokens/anchor_tokens.dart mobile/lib/features/notes/presentation/editor/highlight_underlay.dart mobile/lib/features/notes/presentation/editor/rich_text_editor.dart mobile/test/widgets/note_search_test.dart
git commit -m "feat(mobile): paint search matches under the note text"
```

---

### Task 4: The search bar

**Files:**
- Create: `mobile/lib/features/notes/presentation/widgets/note_search_bar.dart`
- Modify: `mobile/lib/l10n/app_en.arb`
- Modify: `mobile/lib/l10n/app_localizations.dart`
- Modify: `mobile/lib/l10n/app_localizations_en.dart`
- Test: `mobile/test/widgets/note_search_test.dart`

**Interfaces:**
- Consumes: `NoteSearch` from Task 1.
- Produces: `class NoteSearchBar extends StatefulWidget` with `NoteSearch search`, `ValueChanged<String> onQueryChanged`, `VoidCallback onNext`, `VoidCallback onPrevious`, `VoidCallback onClose`, `Color background`.

- [ ] **Step 1: Write the failing test**

Append to `mobile/test/widgets/note_search_test.dart`:

```dart
  testWidgets('the bar counts the matches and steps through them', (
    tester,
  ) async {
    var search = const NoteSearch(
      query: 'tram',
      matches: [TextRange(start: 0, end: 4), TextRange(start: 5, end: 9)],
    );
    var nexts = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: NoteSearchBar(
              search: search,
              background: Colors.white,
              onQueryChanged: (_) {},
              onNext: () => setState(() {
                nexts++;
                search = search.copyWith(active: 1);
              }),
              onPrevious: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.arrowDown));
    await tester.pumpAndSettle();

    expect(nexts, 1);
    expect(find.text('2/2'), findsOneWidget);
  });
```

Add the import:

```dart
import 'package:anchor/features/notes/presentation/widgets/note_search_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/widgets/note_search_test.dart`
Expected: FAIL — `NoteSearchBar` is not defined.

- [ ] **Step 3: Write minimal implementation**

`mobile/lib/l10n/app_en.arb`, before `"settingsMoveChecked"`:

```json
  "noteSearch": "Search in this note",
  "@noteSearch": {
    "description": "Label of the button in a note's top bar that opens the search field."
  },
  "noteSearchHint": "Find in note",
  "@noteSearchHint": {
    "description": "Placeholder inside the note's search field."
  },
  "noteSearchNoResults": "No results",
  "@noteSearchNoResults": {
    "description": "Shown in the note's search bar when the query matches nothing."
  },
  "noteSearchNext": "Next match",
  "@noteSearchNext": {
    "description": "Label of the down arrow that moves to the next search match."
  },
  "noteSearchPrevious": "Previous match",
  "@noteSearchPrevious": {
    "description": "Label of the up arrow that moves to the previous search match."
  },
  "noteSearchClose": "Close search",
  "@noteSearchClose": {
    "description": "Label of the button that closes the note's search."
  },
```

`mobile/lib/l10n/app_localizations.dart`, before the `settingsMoveChecked` getter:

```dart
  /// Label of the button in a note's top bar that opens the search field.
  ///
  /// In en, this message translates to:
  /// **'Search in this note'**
  String get noteSearch;

  /// Placeholder inside the note's search field.
  ///
  /// In en, this message translates to:
  /// **'Find in note'**
  String get noteSearchHint;

  /// Shown in the note's search bar when the query matches nothing.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noteSearchNoResults;

  /// Label of the down arrow that moves to the next search match.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get noteSearchNext;

  /// Label of the up arrow that moves to the previous search match.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get noteSearchPrevious;

  /// Label of the button that closes the note's search.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get noteSearchClose;

```

`mobile/lib/l10n/app_localizations_en.dart`, before the `settingsMoveChecked` getter:

```dart
  @override
  String get noteSearch => 'Search in this note';

  @override
  String get noteSearchHint => 'Find in note';

  @override
  String get noteSearchNoResults => 'No results';

  @override
  String get noteSearchNext => 'Next match';

  @override
  String get noteSearchPrevious => 'Previous match';

  @override
  String get noteSearchClose => 'Close search';

```

`mobile/lib/features/notes/presentation/widgets/note_search_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../l10n/l10n.dart';
import '../editor/note_search.dart';

/// The note's top bar while a search is open: a field, a counter, two arrows
/// and a close button.
class NoteSearchBar extends StatefulWidget {
  const NoteSearchBar({
    super.key,
    required this.search,
    required this.background,
    required this.onQueryChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
  });

  final NoteSearch search;
  final Color background;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;

  @override
  State<NoteSearchBar> createState() => _NoteSearchBarState();
}

class _NoteSearchBarState extends State<NoteSearchBar> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  String? get _counter {
    if (widget.search.isEmpty) return null;
    if (!widget.search.hasMatches) return context.l10n.noteSearchNoResults;
    final count = widget.search.matches.length;
    final shown = count >= maxSearchMatches ? '$maxSearchMatches+' : '$count';
    return '${widget.search.active + 1}/$shown';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasMatches = widget.search.hasMatches;
    return Material(
      color: widget.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AnchorTokens.space8,
            vertical: AnchorTokens.space8,
          ),
          child: Row(
            spacing: 4,
            children: [
              BarButton(
                icon: LucideIcons.arrowLeft,
                label: l10n.noteSearchClose,
                onPressed: widget.onClose,
              ),
              Expanded(
                child: TextField(
                  controller: _field,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: widget.onQueryChanged,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: l10n.noteSearchHint,
                  ),
                ),
              ),
              if (_counter case final counter?)
                Text(
                  counter,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              BarButton(
                icon: LucideIcons.arrowUp,
                label: l10n.noteSearchPrevious,
                onPressed: hasMatches ? widget.onPrevious : null,
              ),
              BarButton(
                icon: LucideIcons.arrowDown,
                label: l10n.noteSearchNext,
                onPressed: hasMatches ? widget.onNext : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/widgets/note_search_test.dart && flutter analyze`
Expected: PASS, 2 tests; analyze reports no issues.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/l10n mobile/lib/features/notes/presentation/widgets/note_search_bar.dart mobile/test/widgets/note_search_test.dart
git commit -m "feat(mobile): add the note search bar"
```

---

### Task 5: Wire the search into the note screen

**Files:**
- Modify: `mobile/lib/features/notes/presentation/widgets/note_bar.dart`
- Modify: `mobile/lib/features/notes/presentation/note_edit_screen.dart`
- Test: `mobile/test/widgets/note_search_test.dart`

**Interfaces:**
- Consumes: `NoteSearchController` (Task 2), `NoteSearchBar` (Task 4), `RichTextEditor.search` (Task 3).
- Produces: `NoteBar({... required VoidCallback onSearch})`.

- [ ] **Step 1: Write the failing test**

Append to `mobile/test/widgets/note_search_test.dart`:

```dart
  testWidgets('the note bar offers a search button', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: NoteBar(
            appearance: NoteAppearance.plain,
            scrollOffset: ScrollOffset.zero,
            reminder: null,
            isUnsynced: false,
            isTrashed: false,
            isReadOnly: false,
            onBack: () {},
            onHistory: () {},
            onBackground: () {},
            onReminder: () {},
            onMore: () {},
            onSearch: () => opened++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.search));
    expect(opened, 1);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/widgets/note_search_test.dart`
Expected: FAIL — `NoteBar` has no `onSearch`.

- [ ] **Step 3: Write minimal implementation**

`mobile/lib/features/notes/presentation/widgets/note_bar.dart`:

- Add the parameter and field:

```dart
    required this.onSearch,
```

```dart
  final VoidCallback onSearch;
```

- Add the button to `actions`, before the palette button:

```dart
        BarButton(
          icon: LucideIcons.search,
          label: context.l10n.noteSearch,
          onPressed: onSearch,
        ),
```

`mobile/lib/features/notes/presentation/note_edit_screen.dart`:

- Add state:

```dart
  late final NoteSearchController _search = NoteSearchController(
    textOf: () => _editorKey.currentState?.controller.document.toPlainText() ?? '',
  );
  bool _isSearching = false;
```

- Dispose it beside the other disposals:

```dart
    _search.dispose();
```

- Add a listener that scrolls to the active match when the search changes:

```dart
  void _onSearchChanged() {
    setState(() {});
    final range = _search.search.activeRange;
    if (range == null) return;
    _editorKey.currentState?.revealRange(range);
  }
```

and register it in `initState`:

```dart
    _search.addListener(_onSearchChanged);
```

- Replace the `bar` with:

```dart
    final bar = _isSearching
        ? NoteSearchBar(
            search: _search.search,
            background: appearance.colors.bg,
            onQueryChanged: _search.setQuery,
            onNext: _search.next,
            onPrevious: _search.previous,
            onClose: _closeSearch,
          )
        : NoteBar(
            // ... the existing arguments ...
            onSearch: _openSearch,
          );
```

- Add the two methods:

```dart
  void _openSearch() => setState(() => _isSearching = true);

  void _closeSearch() {
    _search.clear();
    setState(() => _isSearching = false);
  }
```

- Pass the search to the editor:

```dart
              search: _search.search,
```

- Add the imports:

```dart
import 'editor/note_search_controller.dart';
import 'widgets/note_search_bar.dart';
```

`mobile/lib/features/notes/presentation/editor/rich_text_editor.dart`, add the reveal method to `RichTextEditorState`:

```dart
  /// Scrolls so [range] is on screen, without touching the selection.
  void revealRange(TextRange range) {
    final render = _editorKey.currentContext?.findRenderObject();
    if (render is! RenderEditor || !render.attached) return;
    final rect = render.getLocalRectForCaret(
      TextPosition(offset: range.start),
    );
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final offset = render.localToGlobal(rect.topLeft, ancestor: box).dy;
    widget.scrollController.animateTo(
      (widget.scrollController.offset + offset - 120).clamp(
        0.0,
        widget.scrollController.position.maxScrollExtent,
      ),
      duration: context.motion(Spring.snappy.duration),
      curve: Spring.snappy.curve,
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/widgets/note_search_test.dart && flutter analyze`
Expected: PASS, 3 tests; analyze reports no issues.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/notes/presentation
git commit -m "feat(mobile): search inside the open note"
```

---

### Task 6: The whole suite

**Files:**
- Test: `mobile/test/widgets/note_search_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces: nothing.

- [ ] **Step 1: Run the whole suite**

Run: `cd mobile && flutter analyze && flutter test`
Expected: analyze reports no issues; every test passes.

- [ ] **Step 2: Fix what the run shows**

Any failure is fixed in the file it names, then the run repeats until it is clean. No test is deleted to make the suite pass.

- [ ] **Step 3: Commit**

```bash
git add mobile
git commit -m "test(mobile): keep the note search suite green"
```
