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
