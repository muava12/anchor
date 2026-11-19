/// The occurrences a repeating reminder has had put off by a snooze, kept
/// per note so a reconcile does not put them back on their old period.
library;

/// Maps a note id to the wall-clock time its current occurrence is snoozed to.
///
/// A repeating reminder keeps its original period (the scheduler reschedules
/// the next one), so the snoozed time lives here instead of in `remindAt`. A
/// reconcile reads this map and holds the snoozed occurrence until its time
/// passes; the scheduler then clears the entry and the next period takes over.
class SnoozedOccurrences {
  const SnoozedOccurrences(this._byNote);

  const SnoozedOccurrences.empty() : _byNote = const {};

  final Map<String, String> _byNote;

  /// The wall-clock time [noteId] is snoozed to, or null when it is not.
  String? atFor(String noteId) => _byNote[noteId];

  /// Whether [noteId] currently has a snoozed occurrence.
  bool contains(String noteId) => _byNote.containsKey(noteId);

  /// The note ids with a snoozed occurrence.
  Iterable<String> get noteIds => _byNote.keys;

  SnoozedOccurrences set(String noteId, String wallClock) =>
      SnoozedOccurrences({..._byNote, noteId: wallClock});

  SnoozedOccurrences remove(String noteId) =>
      SnoozedOccurrences({..._byNote}..remove(noteId));

  /// The JSON the preferences store keeps: a flat `{noteId: wallClock}` map.
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_byNote);

  /// Rebuilds from stored JSON, dropping any entry that is not a string pair.
  factory SnoozedOccurrences.fromJson(Object? json) {
    if (json is! Map) return const SnoozedOccurrences.empty();
    final byNote = <String, String>{};
    for (final entry in json.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String && value is String) byNote[key] = value;
    }
    return SnoozedOccurrences(byNote);
  }
}
