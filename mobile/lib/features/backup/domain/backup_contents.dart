class BackupTag {
  const BackupTag({
    required this.id,
    required this.name,
    this.color,
    this.version,
  });

  final String id;
  final String name;
  final String? color;

  /// The server version this tag was written against, kept for the same reason
  /// a note keeps its own.
  final int? version;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'version': version,
  };

  factory BackupTag.fromJson(Map<String, dynamic> json) => BackupTag(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as String?,
    version: json['version'] as int?,
  );
}

class BackupAttachment {
  const BackupAttachment({
    required this.id,
    required this.type,
    required this.originalFilename,
    required this.mimeType,
    required this.fileSize,
    required this.position,
    required this.file,
  });

  final String id;
  final String type;
  final String originalFilename;
  final String mimeType;
  final int fileSize;
  final int position;

  /// The path inside the zip, such as `attachments/a1.jpg`.
  final String file;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'originalFilename': originalFilename,
    'mimeType': mimeType,
    'fileSize': fileSize,
    'position': position,
    'file': file,
  };

  factory BackupAttachment.fromJson(Map<String, dynamic> json) =>
      BackupAttachment(
        id: json['id'] as String,
        type: json['type'] as String,
        originalFilename: json['originalFilename'] as String,
        mimeType: json['mimeType'] as String,
        fileSize: json['fileSize'] as int,
        position: json['position'] as int,
        file: json['file'] as String,
      );
}

class BackupNote {
  const BackupNote({
    required this.id,
    required this.title,
    required this.content,
    required this.isPinned,
    required this.isArchived,
    required this.background,
    required this.state,
    required this.updatedAt,
    required this.version,
    required this.reminderAt,
    required this.reminderRecurrence,
    required this.tagIds,
    required this.attachments,
  });

  final String id;
  final String title;
  final String? content;
  final bool isPinned;
  final bool isArchived;
  final String? background;
  final String state;
  final DateTime? updatedAt;

  /// The server version this note was written against. Null when the server
  /// has never seen it. Restore keeps it so the server can tell an unchanged
  /// note from one edited after the backup.
  final int? version;

  final String? reminderAt;
  final String? reminderRecurrence;
  final List<String> tagIds;
  final List<BackupAttachment> attachments;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'isPinned': isPinned,
    'isArchived': isArchived,
    'background': background,
    'state': state,
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
    'version': version,
    'reminderAt': reminderAt,
    'reminderRecurrence': reminderRecurrence,
    'tagIds': tagIds,
    'attachments': [for (final attachment in attachments) attachment.toJson()],
  };

  factory BackupNote.fromJson(Map<String, dynamic> json) => BackupNote(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String?,
    isPinned: json['isPinned'] as bool,
    isArchived: json['isArchived'] as bool,
    background: json['background'] as String?,
    state: json['state'] as String,
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.parse(json['updatedAt'] as String),
    version: json['version'] as int?,
    reminderAt: json['reminderAt'] as String?,
    reminderRecurrence: json['reminderRecurrence'] as String?,
    tagIds: [for (final id in json['tagIds'] as List) id as String],
    attachments: [
      for (final attachment in json['attachments'] as List)
        BackupAttachment.fromJson(attachment as Map<String, dynamic>),
    ],
  );
}

class BackupContents {
  const BackupContents({required this.tags, required this.notes});

  final List<BackupTag> tags;
  final List<BackupNote> notes;

  Map<String, dynamic> toJson() => {
    'tags': [for (final tag in tags) tag.toJson()],
    'notes': [for (final note in notes) note.toJson()],
  };

  factory BackupContents.fromJson(Map<String, dynamic> json) => BackupContents(
    tags: [
      for (final tag in json['tags'] as List)
        BackupTag.fromJson(tag as Map<String, dynamic>),
    ],
    notes: [
      for (final note in json['notes'] as List)
        BackupNote.fromJson(note as Map<String, dynamic>),
    ],
  );
}
