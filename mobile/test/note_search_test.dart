import 'package:anchor/features/notes/presentation/editor/note_search.dart';
import 'package:anchor/features/notes/presentation/editor/note_search_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds every occurrence whatever the case', () {
    final ranges = findMatches('Tram 28 and the tram stop', 'tram');
    expect(ranges, const [
      TextRange(start: 0, end: 4),
      TextRange(start: 16, end: 20),
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
}
