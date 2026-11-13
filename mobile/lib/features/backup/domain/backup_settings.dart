class BackupSettings {
  const BackupSettings({
    this.folderUri,
    this.automatic = true,
    this.periodDays = 7,
    this.keepFiles = 3,
    this.password,
    this.lastBackupAt,
  });

  static const int minPeriodDays = 1;
  static const int maxPeriodDays = 31;
  static const int minKeepFiles = 1;
  static const int maxKeepFiles = 10;

  final String? folderUri;
  final bool automatic;
  final int periodDays;
  final int keepFiles;
  final String? password;
  final DateTime? lastBackupAt;

  bool get hasFolder => folderUri != null && folderUri!.isNotEmpty;

  BackupSettings copyWith({
    String? folderUri,
    bool? automatic,
    int? periodDays,
    int? keepFiles,
    String? password,
    DateTime? lastBackupAt,
    bool clearFolder = false,
    bool clearPassword = false,
  }) => BackupSettings(
    folderUri: clearFolder ? null : (folderUri ?? this.folderUri),
    automatic: automatic ?? this.automatic,
    periodDays: periodDays ?? this.periodDays,
    keepFiles: keepFiles ?? this.keepFiles,
    password: clearPassword ? null : (password ?? this.password),
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
  );
}
