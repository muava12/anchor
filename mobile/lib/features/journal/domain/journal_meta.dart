import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../notes/domain/note_blocks.dart';

enum JournalMood { amazing, good, neutral, rough }

extension JournalMoodX on JournalMood {
  String get emoji => switch (this) {
    JournalMood.amazing => '😄',
    JournalMood.good => '🙂',
    JournalMood.neutral => '😐',
    JournalMood.rough => '🙁',
  };
}

JournalMood? journalMoodFromName(String? name) {
  final value = name?.trim().toLowerCase();
  for (final mood in JournalMood.values) {
    if (mood.name == value) return mood;
  }
  return null;
}

/// The mood and the entry day/time, plus any key the app does not know.
@immutable
class JournalMeta {
  const JournalMeta({this.mood, this.entryAt, this.extras = const {}});

  final JournalMood? mood;

  /// Local wall clock, from the `date` and `time` lines.
  final DateTime? entryAt;

  /// Unknown header keys, kept so a rewrite does not drop them.
  final Map<String, String> extras;

  bool get isEmpty => mood == null && entryAt == null && extras.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is JournalMeta &&
      other.mood == mood &&
      other.entryAt == entryAt &&
      mapEquals(other.extras, extras);

  @override
  int get hashCode => Object.hash(mood, entryAt, Object.hashAll(extras.entries));
}

/// A stored note split into its metadata header and its body.
@immutable
class JournalEntry {
  const JournalEntry({required this.meta, required this.body});

  final JournalMeta meta;

  /// The body as ops JSON, or the original content when no header was found.
  final String? body;
}

const _knownKeys = {'mood', 'date', 'time'};

/// Reads a leading `key: value` block ended by a `---` line.
///
/// A note without a leading block returns an empty meta and the content as-is,
/// so the body is never lost.
JournalEntry parseJournalContent(String? content) {
  final empty = JournalEntry(meta: const JournalMeta(), body: content);
  final ops = decodeNoteOps(content);
  if (ops.isEmpty) return empty;

  final first = ops.first;
  if (first is! Map) return empty;
  final insert = first['insert'];
  if (insert is! String) return empty;

  final lines = insert.split('\n');
  var separator = -1;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim() == '---') {
      separator = i;
      break;
    }
  }
  if (separator <= 0) return empty;

  final header = <String, String>{};
  for (final line in lines.sublist(0, separator)) {
    final colon = line.indexOf(':');
    if (colon <= 0) return empty;
    final key = line.substring(0, colon).trim().toLowerCase();
    if (key.isEmpty) return empty;
    header[key] = line.substring(colon + 1).trim();
  }
  if (!header.keys.any(_knownKeys.contains)) return empty;

  final date = _parseDate(header['date']);
  final time = _parseTime(header['time']);
  final entryAt = date != null && time != null
      ? DateTime(date.year, date.month, date.day, time.$1, time.$2)
      : null;
  final extras = {
    for (final entry in header.entries)
      if (!_knownKeys.contains(entry.key)) entry.key: entry.value,
  };

  final rest = lines.length > separator + 1
      ? lines.sublist(separator + 1).join('\n')
      : '';
  final bodyOps = <dynamic>[
    if (rest.isNotEmpty) {'insert': rest},
    ...ops.skip(1),
  ];
  final body = bodyOps.isEmpty ? null : jsonEncode({'ops': bodyOps});

  return JournalEntry(
    meta: JournalMeta(mood: journalMoodFromName(header['mood']), entryAt: entryAt, extras: extras),
    body: body,
  );
}

/// Writes the header back in front of [body]. An empty meta returns it as-is.
String? composeJournalContent(JournalMeta meta, String? body) {
  if (meta.isEmpty) return body;

  final lines = <String>[];
  final mood = meta.mood;
  if (mood != null) lines.add('mood: ${mood.name}');
  final entryAt = meta.entryAt;
  if (entryAt != null) {
    lines.add('date: ${_formatDate(entryAt)}');
    lines.add('time: ${_formatTime(entryAt)}');
  }
  for (final entry in meta.extras.entries) {
    lines.add('${entry.key}: ${entry.value}');
  }
  lines.add('---');
  final header = '${lines.join('\n')}\n';

  return jsonEncode({
    'ops': [
      {'insert': header},
      ...decodeNoteOps(body),
    ],
  });
}

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _formatTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

DateTime? _parseDate(String? value) {
  if (value == null) return null;
  final parts = value.trim().split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

(int, int)? _parseTime(String? value) {
  if (value == null) return null;
  final parts = value.trim().split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return (hour, minute);
}
