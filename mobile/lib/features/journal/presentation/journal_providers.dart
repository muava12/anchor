import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notes/data/repository/notes_repository.dart';
import '../../notes/domain/note.dart';
import '../../tags/domain/tag.dart';
import '../../tags/presentation/tags_controller.dart';

/// The tag named `journal`, compared without case.
Tag? journalTagOf(List<Tag> tags) {
  for (final tag in tags) {
    if (tag.name.toLowerCase() == 'journal') return tag;
  }
  return null;
}

/// The notes carrying [journalTagId]. A missing tag lists nothing.
List<Note> journalNotesOf(List<Note> notes, String? journalTagId) {
  if (journalTagId == null) return const [];
  return [
    for (final note in notes)
      if (note.tagIds.contains(journalTagId)) note,
  ];
}

final journalTagProvider = Provider<Tag?>((ref) {
  final tags = ref.watch(tagsControllerProvider).value ?? const <Tag>[];
  return journalTagOf(tags);
});

final journalNotesProvider = StreamProvider<List<Note>>((ref) {
  final tag = ref.watch(journalTagProvider);
  if (tag == null) return Stream.value(const <Note>[]);
  return ref.watch(notesRepositoryProvider).watchNotes(tagId: tag.id);
});

final journalQueryProvider =
    NotifierProvider<JournalQuery, String>(JournalQuery.new);

class JournalQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}
