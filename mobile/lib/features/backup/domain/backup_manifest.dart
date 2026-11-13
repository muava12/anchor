/// The first file in a backup. It names the format so a later version can
/// refuse a file it does not understand.
class BackupManifest {
  const BackupManifest({
    required this.format,
    required this.app,
    required this.appVersion,
    required this.createdAt,
    required this.notes,
    required this.attachments,
  });

  static const int currentFormat = 1;

  final int format;
  final String app;
  final String appVersion;
  final DateTime createdAt;
  final int notes;
  final int attachments;

  Map<String, dynamic> toJson() => {
    'format': format,
    'app': app,
    'appVersion': appVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'notes': notes,
    'attachments': attachments,
  };

  factory BackupManifest.fromJson(Map<String, dynamic> json) => BackupManifest(
    format: json['format'] as int,
    app: json['app'] as String,
    appVersion: json['appVersion'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    notes: json['notes'] as int,
    attachments: json['attachments'] as int,
  );
}
