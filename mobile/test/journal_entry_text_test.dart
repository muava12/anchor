import 'dart:convert';

import 'package:anchor/core/text/date_formats.dart';
import 'package:anchor/features/journal/domain/journal_day.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/journal_entry_text.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:flutter_test/flutter_test.dart';

Note noteWithBody(String body) => Note(
  id: 'n',
  title: '',
  content: jsonEncode({
    'ops': [
      {'insert': body},
    ],
  }),
);

Note noteWith({int previews = 0, int attachments = 0}) => Note(
  id: 'n',
  title: '',
  content: '{}',
  imagePreviewData: [
    for (var i = 0; i < previews; i++)
      NoteImagePreview(attachmentId: 'a$i', noteId: 'n', filename: '$i.jpg'),
  ],
  attachmentCount: attachments,
);

void main() {
  group('gmtLabel', () {
    test('whole hours are unpadded', () {
      expect(gmtLabel(420), 'GMT+7');
      expect(gmtLabel(0), 'GMT+0');
      expect(gmtLabel(-300), 'GMT-5');
    });
    test('fractional hours keep the minutes', () {
      expect(gmtLabel(330), 'GMT+5:30');
      expect(gmtLabel(-495), 'GMT-8:15');
    });
  });

  group('journal card text helpers', () {
    final note = Note(id: 'n', title: '', content: '{}');

    test('day separator', () {
      expect(
        journalDaySeparator(DateTime(2026, 11, 19)),
        'November 19, 2026 \u00b7 Thu',
      );
    });

    test('time label adds GMT only when tz is known', () {
      final at = DateTime(2026, 11, 19, 8, 12);
      expect(
        journalTimeLabel(
          JournalDayEntry(
            note: note,
            meta: JournalMeta(entryAt: at, tzOffset: 420),
          ),
        ),
        endsWith(' \u00b7 GMT+7'),
      );
      expect(
        journalTimeLabel(
          JournalDayEntry(
            note: note,
            meta: JournalMeta(entryAt: at),
          ),
        ),
        clockLabel(at),
      );
    });

    test('a time label without a time is empty', () {
      expect(
        journalTimeLabel(
          JournalDayEntry(note: note, meta: const JournalMeta()),
        ),
        '',
      );
    });

    test('lead is short without newline up to 90 chars', () {
      expect(isShortLead('a' * 90), isTrue);
      expect(isShortLead('a' * 91), isFalse);
      expect(isShortLead('one\ntwo'), isFalse);
    });

    test('lead of a whitespace-only body is empty', () {
      expect(journalLeadOf(noteWithBody('  \n ')), '');
    });

    test('location from extras', () {
      expect(
        journalLocationOf(
          const JournalMeta(extras: {'location': ' Dago, Bandung '}),
        ),
        'Dago, Bandung',
      );
      expect(journalLocationOf(const JournalMeta()), isNull);
    });

    test('more images only when four previews exist', () {
      expect(journalMoreImages(noteWith(previews: 4, attachments: 6)), 2);
      expect(journalMoreImages(noteWith(previews: 2, attachments: 6)), 0);
    });

    test('display tags keep note order and drop the journal tag', () {
      final shown = journalDisplayTags(
        Note(id: 'n', title: '', content: '{}', tagIds: ['t', 'j', 'a']),
        [
          Tag(id: 'a', name: 'A'),
          Tag(id: 'j', name: 'J'),
          Tag(id: 't', name: 'T'),
        ],
        'j',
      );
      expect(shown.map((t) => t.id).toList(), ['t', 'a']);
    });
  });
}
