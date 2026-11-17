import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/notes/domain/note_blocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseJournalContent', () {
    test('reads mood, date, time and the body', () {
      const content =
          '{"ops":[{"insert":"mood: good\\ndate: 2026-11-17\\ntime: 09:41\\n---\\nMorning pages\\n"}]}';
      final entry = parseJournalContent(content);
      expect(entry.meta.mood, JournalMood.good);
      expect(entry.meta.entryAt, DateTime(2026, 11, 17, 9, 41));
      expect(entry.body, contains('Morning pages'));
    });

    test('keys are case-insensitive and in any order', () {
      const content =
          '{"ops":[{"insert":"Mood: Rough\\nTIME: 21:05\\nDate: 2026-01-02\\n---\\nx\\n"}]}';
      final entry = parseJournalContent(content);
      expect(entry.meta.mood, JournalMood.rough);
      expect(entry.meta.entryAt, DateTime(2026, 1, 2, 21, 5));
    });

    test('a plain text note with no separator has no metadata', () {
      const content = 'Just a note';
      final entry = parseJournalContent(content);
      expect(entry.meta.isEmpty, isTrue);
      expect(entry.body, 'Just a note');
    });

    test('a separator after body text is not metadata', () {
      const content = '{"ops":[{"insert":"Hello\\n---\\nworld\\n"}]}';
      final entry = parseJournalContent(content);
      expect(entry.meta.isEmpty, isTrue);
      expect(entry.body, content);
    });

    test('a date without a time leaves entryAt null', () {
      const content =
          '{"ops":[{"insert":"date: 2026-11-17\\n---\\nx\\n"}]}';
      final entry = parseJournalContent(content);
      expect(entry.meta.entryAt, isNull);
    });

    test('unknown keys are kept in extras', () {
      const content =
          '{"ops":[{"insert":"mood: good\\nweather: sunny\\n---\\nx\\n"}]}';
      final entry = parseJournalContent(content);
      expect(entry.meta.extras['weather'], 'sunny');
      final composed = composeJournalContent(entry.meta, entry.body)!;
      expect(composed, contains('weather: sunny'));
    });

    test('an empty body composes to one header op only', () {
      final meta = JournalMeta(
        mood: JournalMood.good,
        entryAt: DateTime(2026, 11, 17, 9, 41),
      );
      final composed = composeJournalContent(meta, null)!;
      expect(decodeNoteOps(composed).length, 1);
    });

    test('a body with formatting round-trips', () {
      const body =
          '{"ops":[{"insert":"bold","attributes":{"bold":true}},{"insert":"\\n"}]}';
      final meta = JournalMeta(
        mood: JournalMood.neutral,
        entryAt: DateTime(2026, 11, 17, 9, 41),
      );
      final entry = parseJournalContent(composeJournalContent(meta, body));
      expect(entry.meta.mood, JournalMood.neutral);
      expect(entry.body, contains('"bold":true'));
    });
  });
}
