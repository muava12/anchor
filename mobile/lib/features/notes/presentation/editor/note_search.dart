import 'package:flutter/foundation.dart';
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
