### Task 1: Backup file model and writer

**Files:**
- Create: `lib/features/backup/domain/backup_manifest.dart`
- Create: `lib/features/backup/domain/backup_contents.dart`
- Create: `lib/features/backup/data/backup_writer.dart`
- Test: `test/backup/backup_writer_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class BackupManifest { final int format; final String app; final String appVersion; final DateTime createdAt; final int notes; final int attachments; Map<String, dynamic> toJson(); factory BackupManifest.fromJson(Map<String, dynamic>); }`
  - `class BackupTag { final String id; final String name; final String? color; }`
  - `class BackupAttachment { final String id; final String type; final String originalFilename; final String mimeType; final int fileSize; final int position; final String file; }`
  - `class BackupNote { final String id; final String title; final String? content; final bool isPinned; final bool isArchived; final String? background; final String state; final DateTime? updatedAt; final int? version; final String? reminderAt; final String? reminderRecurrence; final List<String> tagIds; final List<BackupAttachment> attachments; }`
  - `class BackupContents { final List<BackupTag> tags; final List<BackupNote> notes; }`
  - `class BackupWriter { BackupWriter(this.path); Future<void> addJson(String name, Map<String, dynamic> json); Future<void> addFile(File source, String name); Future<void> close(); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/backup_writer_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:anchor/features/backup/data/backup_writer.dart';
import 'package:anchor/features/backup/domain/backup_contents.dart';
import 'package:anchor/features/backup/domain/backup_manifest.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('backup_writer'));
  tearDown(() => folder.deleteSync(recursive: true));

  test('writes the manifest, the notes and an attachment', () async {
    final photo = File('${folder.path}/photo.jpg')
      ..writeAsBytesSync([1, 2, 3, 4]);
    final zipPath = '${folder.path}/out.zip';

    final writer = BackupWriter(zipPath);
    await writer.addJson('manifest.json', {
      'format': 1,
      'app': 'anchor',
      'appVersion': '0.22.2',
      'createdAt': '2026-11-14T05:30:00.000Z',
      'notes': 1,
      'attachments': 1,
    });
    await writer.addJson('notes.json', {
      'tags': [
        {'id': 't1', 'name': 'molagis', 'color': null},
      ],
      'notes': [
        {
          'id': 'n1',
          'title': 'Groceries',
          'content': null,
          'isPinned': false,
          'isArchived': false,
          'background': null,
          'state': 'active',
          'updatedAt': '2026-11-13T10:44:43.093Z',
          'version': 7,
          'reminderAt': null,
          'reminderRecurrence': null,
          'tagIds': ['t1'],
          'attachments': [
            {
              'id': 'a1',
              'type': 'image',
              'originalFilename': 'photo.jpg',
              'mimeType': 'image/jpeg',
              'fileSize': 4,
              'position': 0,
              'file': 'attachments/a1.jpg',
            },
          ],
        },
      ],
    });
    await writer.addFile(photo, 'attachments/a1.jpg');
    await writer.close();

    final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
    expect(
      archive.files.map((file) => file.name),
      containsAll(['manifest.json', 'notes.json', 'attachments/a1.jpg']),
    );

    final notes = jsonDecode(
      utf8.decode(archive.findFile('notes.json')!.content as List<int>),
    ) as Map<String, dynamic>;
    expect((notes['notes'] as List).single['title'], 'Groceries');
    expect(archive.findFile('attachments/a1.jpg')!.content, [1, 2, 3, 4]);
  });

  test('a manifest round trips through json', () {
    final manifest = BackupManifest(
      format: 1,
      app: 'anchor',
      appVersion: '0.22.2',
      createdAt: DateTime.utc(2026, 11, 14, 5, 30),
      notes: 61,
      attachments: 6,
    );
    final back = BackupManifest.fromJson(manifest.toJson());
    expect(back.format, 1);
    expect(back.notes, 61);
    expect(back.createdAt, DateTime.utc(2026, 11, 14, 5, 30));
  });

  test('a note round trips through json', () {
    final note = BackupNote(
      id: 'n1',
      title: 'Groceries',
      content: '{"ops":[]}',
      isPinned: true,
      isArchived: false,
      background: null,
      state: 'active',
      updatedAt: DateTime.utc(2026, 11, 13, 10, 44, 43),
      version: 7,
      reminderAt: '2026-11-20T08:00',
      reminderRecurrence: 'daily',
      tagIds: const ['t1'],
      attachments: const [],
    );
    final back = BackupNote.fromJson(note.toJson());
    expect(back.id, 'n1');
    expect(back.isPinned, isTrue);
    expect(back.version, 7);
    expect(back.reminderAt, '2026-11-20T08:00');
    expect(back.tagIds, ['t1']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/backup_writer_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:anchor/features/backup/...'`

- [ ] **Step 3: Write the models**

```dart
// lib/features/backup/domain/backup_manifest.dart
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
```

```dart
// lib/features/backup/domain/backup_contents.dart
class BackupTag {
  const BackupTag({required this.id, required this.name, this.color});

  final String id;
  final String name;
  final String? color;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  factory BackupTag.fromJson(Map<String, dynamic> json) => BackupTag(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as String?,
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
```

- [ ] **Step 4: Write the writer**

```dart
// lib/features/backup/data/backup_writer.dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

/// Writes a zip to disk one entry at a time, so a large attachment never sits
/// in memory.
class BackupWriter {
  BackupWriter(this.path) {
    _encoder.create(path);
  }

  final String path;
  final ZipFileEncoder _encoder = ZipFileEncoder();

  Future<void> addJson(String name, Map<String, dynamic> json) async {
    final bytes = utf8.encode(jsonEncode(json));
    _encoder.addArchiveFile(
      ArchiveFile(name, bytes.length, bytes),
    );
  }

  Future<void> addFile(File source, String name) async {
    _encoder.addFile(source, name);
  }

  Future<void> close() async {
    _encoder.close();
  }
}
```

- [ ] **Step 5: Add the dependency**

In `mobile/pubspec.yaml`, under `dependencies:`, add `archive: ^4.5.2` next to the other entries. Do not change the resolved version.

- [ ] **Step 6: Run the test to verify it passes**

Run: `cd mobile && flutter pub get && flutter test test/backup/backup_writer_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 7: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/lib/features/backup mobile/test/backup
git commit -m "feat: write a backup zip with a manifest and the notes"
```

---

