# Search inside a note — design

Date: 2026-11-13
Status: approved for planning

## Problem

A long note cannot be searched. The list screen searches titles and bodies
across notes, but once a note is open there is no way to find a word in it. A
person scrolls and reads.

NotallyX has this: a search button in the note's toolbar opens a field, every
match is highlighted, a counter reads "3/12", and two arrows step through the
matches.

## Goal

The same, in Anchor's note screen:

- A search button in the note's top bar.
- While searching, the bar becomes a field with a counter, an up arrow, a down
  arrow, and a close button.
- Every match is highlighted; the active match is highlighted more strongly.
- The arrows move between matches and the page scrolls to the active one.

## What already exists

- `lib/features/notes/presentation/editor/rich_text_editor.dart` holds one
  `QuillEditor` bound to a `QuillController`. The document is a Delta, so the
  plain text is `controller.document.toPlainText()`.
- `lib/features/notes/presentation/editor/highlight_underlay.dart` is a
  `CustomPainter` that paints under the editor's text. It already walks the
  document's nodes and asks the `RenderEditor` for caret geometry, and it paints
  the dragged checklist line today. It paints; it never edits the document.
- `lib/features/notes/presentation/widgets/note_bar.dart` is the note's top bar,
  with `BarButton` actions (palette, reminder, more) and a `PageBar` underneath.

The underlay is the reason this feature is small: highlighting a range needs no
change to the document, so a search never marks the note dirty and never syncs.

## Design

### Finding matches

`lib/features/notes/presentation/editor/note_search.dart`:

```dart
class NoteSearch {
  const NoteSearch({this.query = '', this.matches = const [], this.active = 0});

  final String query;
  final List<TextRange> matches;
  final int active;
}
```

`findMatches(String text, String query)` returns the ranges:

- Case-insensitive, using `toLowerCase()` on both sides.
- No regular expressions: a query is literal text.
- Matches do not overlap: after a hit, the scan continues past its end.
- An empty or whitespace-only query returns no matches.
- At most 500 matches. Past that the list stops; the counter shows "500+".

### Holding the state

`NoteSearchController extends ChangeNotifier`, owned by the note screen:

- `query`, `matches`, `active`.
- `setQuery(String)` debounces 150 ms, then recomputes against the current
  document text and resets `active` to 0.
- `next()` and `previous()` move `active` and wrap around.
- `clear()` empties the query and the matches.
- The controller listens to the document: when the text changes while a search
  is open, it recomputes, keeping `active` inside the new range.

### Painting the matches

`HighlightUnderlay` gains an optional `NoteSearch` and a highlight colour pair:

- Every match is painted with the soft highlight.
- The active match is painted with the stronger one.
- The painter repaints when the search controller notifies, through the same
  `Listenable` it already takes.

Colours come from the note's appearance palette, so a coloured note keeps its
contrast. Two new tokens: `searchHighlight` and `searchHighlightActive`.

### Moving to a match

The screen scrolls so the active match is visible, using the caret geometry the
underlay already asks for. The editor's selection and focus do not change: the
person keeps typing in the search field, and the note is not edited.

### The bar

`NoteBar` gains `onSearch`, and shows a `BarButton` with `LucideIcons.search`
before the palette button. It is shown for read-only, shared and trashed notes
too: searching does not edit anything.

While a search is open, the note screen shows `NoteSearchBar` in place of
`NoteBar`:

- A back arrow that closes the search.
- A `TextField` with autofocus, the note's own text style, and a clear button
  when it holds text.
- The counter: "3/12", or "500+" at the cap, or nothing while the query is
  empty.
- An up arrow and a down arrow, disabled while there are no matches.
- A close button, which also closes the search.

Back and Escape close the search and restore the bar. Closing clears the
highlights.

### What does not change

- The document. No attribute is written, so the note stays clean and nothing
  syncs.
- The list screen's search across notes.
- The editor's own selection and focus.

## Testing

Unit tests, `test/note_search_test.dart`:

- A query finds every occurrence, whatever the case.
- Matches do not overlap: "aa" in "aaaa" gives two matches, not three.
- An empty or whitespace query gives no matches.
- A query with no hit gives an empty list.
- More than 500 hits stop at 500.
- `next()` and `previous()` wrap around, and do nothing with no matches.

Widget test, `test/widgets/note_search_test.dart`:

- The note bar shows the search button.
- Tapping it replaces the bar with the field, focused.
- Typing "tram" in a note with three hits shows "1/3".
- The down arrow shows "2/3"; the up arrow returns to "1/3".
- Closing restores the note bar and removes the highlights.

## Risks

- Painting many matches on a very long note costs time. The 500 cap bounds it,
  and the painter only draws ranges that are on screen.
- Recomputing on every document change while a search is open could be costly on
  a large note. The debounce covers typing in the field; document changes are
  recomputed at most once per frame.
