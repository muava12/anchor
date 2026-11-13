/// How a restore treats the ids in the backup.
enum RestoreMode {
  /// The same account: keep the ids and the server versions, so the server can
  /// tell an unchanged note from one edited after the backup.
  keepIds,

  /// Any account: fresh ids and no version, so the server creates every note.
  newIds,
}
