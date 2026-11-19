import 'package:anchor/core/text/date_formats.dart';
import 'package:anchor/features/journal/domain/journal_day.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/journal_entry_text.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final note = Note(id: 'n', title: '', content: '{}');
  final current = DateTime.now().timeZoneOffset.inMinutes;

  JournalDay day(DateTime day, int? tzOffset) => JournalDay(
    day: day,
    entries: [JournalDayEntry(note: note, meta: JournalMeta(tzOffset: tzOffset))],
  );

  group('gmtLabel', () {
    test('whole hours', () {
      expect(gmtLabel(420), 'GMT+07');
      expect(gmtLabel(0), 'GMT+00');
      expect(gmtLabel(-300), 'GMT-05');
    });
    test('fractional hours', () {
      expect(gmtLabel(330), 'GMT+05:30');
      expect(gmtLabel(-495), 'GMT-08:15');
    });
  });

  group('journalDayHeader', () {
    test('today uses the relative word', () {
      final now = DateTime(2026, 11, 17, 12);
      final header = journalDayHeader(day(now, null), l10n, now: now);
      expect(header, startsWith('TODAY, '));
      expect(header, contains('2026'));
    });

    test('yesterday uses the relative word', () {
      final now = DateTime(2026, 11, 17, 12);
      final yday = DateTime(2026, 11, 16, 12);
      final header = journalDayHeader(day(yday, null), l10n, now: now);
      expect(header, startsWith('YESTERDAY, '));
    });

    test('an other day uses the weekday name', () {
      // 2026-11-09 is a Monday, 2026-11-20 is the "now".
      final now = DateTime(2026, 11, 20, 12);
      final mon = DateTime(2026, 11, 9, 12);
      final expected = DateFormat('EEEE', dateLocale).format(mon).toUpperCase();
      final header = journalDayHeader(day(mon, null), l10n, now: now);
      expect(header, startsWith('$expected, '));
      expect(header, contains('2026'));
    });

    test('shows the GMT suffix when the entry tz differs', () {
      final now = DateTime(2026, 11, 17, 12);
      final different = current + 360;
      final header = journalDayHeader(day(now, different), l10n, now: now);
      expect(header, contains('· GMT'));
    });

    test('omits the GMT suffix when the entry tz matches', () {
      final now = DateTime(2026, 11, 17, 12);
      final header = journalDayHeader(day(now, current), l10n, now: now);
      expect(header, isNot(contains('· GMT')));
    });
  });
}
