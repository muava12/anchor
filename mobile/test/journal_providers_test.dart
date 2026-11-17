import 'package:anchor/features/journal/presentation/journal_providers.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('journalTagOf finds the tag by name, any case', () {
    const tags = [Tag(id: 't1', name: 'Journal'), Tag(id: 't2', name: 'work')];
    expect(journalTagOf(tags)?.id, 't1');
    expect(journalTagOf(const <Tag>[]), isNull);
  });

  test('journalNotesOf keeps only notes carrying the tag', () {
    const notes = [
      Note(id: 'a', title: 'A', tagIds: ['t1']),
      Note(id: 'b', title: 'B'),
    ];
    expect([for (final n in journalNotesOf(notes, 't1')) n.id], ['a']);
    expect(journalNotesOf(notes, null), isEmpty);
  });
}
