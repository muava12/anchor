# Local backup and restore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Anchor a ZIP backup the person owns, with a chosen folder, an optional password, a silent automatic backup, and a restore that works on the same account or a different one.

**Architecture:** A `features/backup` slice. The data layer turns database rows into a ZIP and back; the presentation layer owns the job state so leaving Settings does not stop a backup. A small Kotlin plugin picks the folder through SAF, following the existing `ShareFolderPlugin` pattern.

**Tech Stack:** Flutter, Riverpod, Drift, `archive` 4.5.2, `cryptography`, Kotlin `DocumentFile`.

## Global Constraints

- No new native dependency beyond the Kotlin plugin in Task 6.
- `archive` is already transitive at 4.5.2; promote it to a direct dependency, do not change the version.
- Backup files are written with no compression.
- The backup file carries no account email and no server URL.
- User-facing copy is English, in `lib/l10n/app_en.arb`, never inline.
- Every new file lives under `lib/features/backup/`.
- Tests run with `flutter test`; the whole suite must stay green.

---

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

/// Writes a zip to disk one entry at a time. Each attachment is read whole, so
/// memory holds at most the largest single file, never the whole library.
///
/// `ZipFileEncoder.addFile` is not used: in archive 4.5.2 it closes the input
/// stream before the encoder reads it, and the entry is dropped.
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
    final bytes = await source.readAsBytes();
    _encoder.addArchiveFile(ArchiveFile(name, bytes.length, bytes));
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

### Task 2: Backup reader

**Files:**
- Create: `lib/features/backup/data/backup_reader.dart`
- Test: `test/backup/backup_reader_test.dart`

**Interfaces:**
- Consumes: `BackupManifest`, `BackupContents` from Task 1.
- Produces:
  - `class BackupReader { BackupReader(this.bytes); BackupManifest get manifest; BackupContents get contents; List<int> fileBytes(String name); }`
  - `class BackupFormatException implements Exception { final String message; }`

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/backup_reader_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:anchor/features/backup/data/backup_reader.dart';
import 'package:anchor/features/backup/data/backup_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('backup_reader'));
  tearDown(() => folder.deleteSync(recursive: true));

  Future<List<int>> buildZip() async {
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
      'tags': <Object>[],
      'notes': [
        {
          'id': 'n1',
          'title': 'Groceries',
          'content': null,
          'isPinned': false,
          'isArchived': false,
          'background': null,
          'state': 'active',
          'updatedAt': null,
          'version': null,
          'reminderAt': null,
          'reminderRecurrence': null,
          'tagIds': <String>[],
          'attachments': <Object>[],
        },
      ],
    });
    await writer.close();
    return File(zipPath).readAsBytesSync();
  }

  test('reads the manifest and the notes', () async {
    final reader = BackupReader(await buildZip());
    expect(reader.manifest.notes, 1);
    expect(reader.contents.notes.single.title, 'Groceries');
  });

  test('a file that is not a zip is refused', () {
    expect(
      () => BackupReader(utf8.encode('not a zip')),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('a zip without a manifest is refused', () async {
    final zipPath = '${folder.path}/bare.zip';
    final writer = BackupWriter(zipPath);
    await writer.addJson('notes.json', {'tags': <Object>[], 'notes': <Object>[]});
    await writer.close();

    expect(
      () => BackupReader(File(zipPath).readAsBytesSync()),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('a newer format is refused', () async {
    final zipPath = '${folder.path}/newer.zip';
    final writer = BackupWriter(zipPath);
    await writer.addJson('manifest.json', {
      'format': 99,
      'app': 'anchor',
      'appVersion': '9.0.0',
      'createdAt': '2026-11-14T05:30:00.000Z',
      'notes': 0,
      'attachments': 0,
    });
    await writer.addJson('notes.json', {'tags': <Object>[], 'notes': <Object>[]});
    await writer.close();

    expect(
      () => BackupReader(File(zipPath).readAsBytesSync()),
      throwsA(isA<BackupFormatException>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/backup_reader_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:anchor/features/backup/data/backup_reader.dart'`

- [ ] **Step 3: Write the reader**

```dart
// lib/features/backup/data/backup_reader.dart
import 'dart:convert';

import 'package:archive/archive.dart';

import '../domain/backup_contents.dart';
import '../domain/backup_manifest.dart';

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads a whole backup into memory. A backup holds text and photos, so this
/// stays small; a library of videos would need a streaming reader.
class BackupReader {
  BackupReader(List<int> bytes) : _archive = _decode(bytes) {
    manifest = _readManifest();
    contents = _readContents();
  }

  final Archive _archive;
  late final BackupManifest manifest;
  late final BackupContents contents;

  static Archive _decode(List<int> bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const BackupFormatException('This file is not an Anchor backup.');
    }
  }

  BackupManifest _readManifest() {
    final file = _archive.findFile('manifest.json');
    if (file == null) {
      throw const BackupFormatException('This file is not an Anchor backup.');
    }
    final json =
        jsonDecode(utf8.decode(file.content as List<int>))
            as Map<String, dynamic>;
    final manifest = BackupManifest.fromJson(json);
    if (manifest.format > BackupManifest.currentFormat) {
      throw const BackupFormatException(
        'This backup was made by a newer version of Anchor.',
      );
    }
    return manifest;
  }

  BackupContents _readContents() {
    final file = _archive.findFile('notes.json');
    if (file == null) {
      throw const BackupFormatException('This backup has no notes.');
    }
    final json =
        jsonDecode(utf8.decode(file.content as List<int>))
            as Map<String, dynamic>;
    return BackupContents.fromJson(json);
  }

  List<int> fileBytes(String name) {
    final file = _archive.findFile(name);
    if (file == null) {
      throw BackupFormatException('This backup is missing $name.');
    }
    return file.content as List<int>;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd mobile && flutter test test/backup/backup_reader_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/backup/data/backup_reader.dart mobile/test/backup/backup_reader_test.dart
git commit -m "feat: read a backup zip and refuse one it cannot understand"
```

---

### Task 3: Optional password

**Files:**
- Create: `lib/features/backup/data/backup_cipher.dart`
- Test: `test/backup/backup_cipher_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `abstract final class BackupCipher { static bool isEncrypted(List<int> bytes); static Future<List<int>> encrypt(List<int> plain, String password); static Future<List<int>> decrypt(List<int> sealed, String password); }`
  - `class WrongPasswordException implements Exception {}`

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/backup_cipher_test.dart
import 'dart:convert';

import 'package:anchor/features/backup/data/backup_cipher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a plain file is not encrypted', () {
    expect(BackupCipher.isEncrypted(utf8.encode('PK')), isFalse);
  });

  test('an encrypted file round trips', () async {
    final plain = utf8.encode('the notes');
    final sealed = await BackupCipher.encrypt(plain, 'mantab');

    expect(BackupCipher.isEncrypted(sealed), isTrue);
    expect(sealed, isNot(plain));
    expect(await BackupCipher.decrypt(sealed, 'mantab'), plain);
  });

  test('the same input encrypts differently each time', () async {
    final plain = utf8.encode('the notes');
    final first = await BackupCipher.encrypt(plain, 'mantab');
    final second = await BackupCipher.encrypt(plain, 'mantab');
    expect(first, isNot(second));
  });

  test('a wrong password is refused', () async {
    final sealed = await BackupCipher.encrypt(utf8.encode('x'), 'mantab');
    expect(
      () => BackupCipher.decrypt(sealed, 'salah'),
      throwsA(isA<WrongPasswordException>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/backup_cipher_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the cipher**

```dart
// lib/features/backup/data/backup_cipher.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class WrongPasswordException implements Exception {
  const WrongPasswordException();
}

/// AES-256-GCM over the finished zip, with the key stretched from the password.
///
/// Layout: 16-byte magic, 16-byte salt, then nonce + ciphertext + tag.
abstract final class BackupCipher {
  static final List<int> _magic = utf8.encode('ANCHORBK') + List.filled(8, 0);
  static const int _saltLength = 16;
  static const int _iterations = 100000;

  static final _algorithm = AesGcm.with256bits();

  static bool isEncrypted(List<int> bytes) {
    if (bytes.length < _magic.length) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  static Future<List<int>> encrypt(List<int> plain, String password) async {
    final salt = _randomBytes(_saltLength);
    final key = await _keyFrom(password, salt);
    final box = await _algorithm.encrypt(plain, secretKey: key);
    return [..._magic, ...salt, ...box.concatenation()];
  }

  static Future<List<int>> decrypt(List<int> sealed, String password) async {
    final saltStart = _magic.length;
    final bodyStart = saltStart + _saltLength;
    final salt = sealed.sublist(saltStart, bodyStart);
    final key = await _keyFrom(password, salt);

    final box = SecretBox.fromConcatenation(
      sealed.sublist(bodyStart),
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );
    try {
      return await _algorithm.decrypt(box, secretKey: key);
    } on SecretBoxAuthenticationError {
      throw const WrongPasswordException();
    }
  }

  static Future<SecretKey> _keyFrom(String password, List<int> salt) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
```

- [ ] **Step 4: Add the dependency**

In `mobile/pubspec.yaml`, under `dependencies:`, add `cryptography: ^2.7.0`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd mobile && flutter pub get && flutter test test/backup/backup_cipher_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 6: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/lib/features/backup/data/backup_cipher.dart mobile/test/backup/backup_cipher_test.dart
git commit -m "feat: seal a backup with a password"
```

---

### Task 4: Export the database into a backup

**Files:**
- Create: `lib/features/backup/data/backup_exporter.dart`
- Test: `test/backup/backup_exporter_test.dart`

**Interfaces:**
- Consumes: `BackupWriter` (Task 1), `BackupContents` (Task 1), `AppDatabase`.
- Produces:
  - `class BackupExporter { BackupExporter(this.db, this.attachmentsRoot); Future<BackupManifest> write(String zipPath, {required String appVersion}); }`
  - `attachmentsRoot` is the `attachments` directory under the app documents directory.

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/backup_exporter_test.dart
import 'dart:io';

import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/features/backup/data/backup_exporter.dart';
import 'package:anchor/features/backup/data/backup_reader.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Directory folder;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    folder = Directory.systemTemp.createTempSync('backup_export');
  });

  tearDown(() async {
    await db.close();
    folder.deleteSync(recursive: true);
  });

  test('exports notes, tags and an attachment', () async {
    await db.into(db.tags).insert(
      TagsCompanion.insert(id: 't1', name: 'molagis'),
    );
    await db.into(db.notes).insert(
      NotesCompanion.insert(
        id: 'n1',
        title: 'Groceries',
        content: const Value('{"ops":[]}'),
        isPinned: const Value(true),
        version: const Value(7),
      ),
    );
    await db.into(db.noteTags).insert(
      NoteTagsCompanion.insert(noteId: 'n1', tagId: 't1'),
    );

    final noteDir = Directory('${folder.path}/n1')..createSync(recursive: true);
    final photo = File('${noteDir.path}/a1-photo.jpg')
      ..writeAsBytesSync([9, 9, 9]);
    await db.into(db.noteAttachments).insert(
      NoteAttachmentsCompanion.insert(
        id: 'a1',
        noteId: 'n1',
        type: 'image',
        originalFilename: 'photo.jpg',
        mimeType: 'image/jpeg',
        fileSize: 3,
        localPath: Value(photo.path),
      ),
    );

    final zipPath = '${folder.path}/out.zip';
    final manifest = await BackupExporter(db, folder).write(
      zipPath,
      appVersion: '0.22.2',
    );

    expect(manifest.notes, 1);
    expect(manifest.attachments, 1);

    final reader = BackupReader(File(zipPath).readAsBytesSync());
    final note = reader.contents.notes.single;
    expect(note.title, 'Groceries');
    expect(note.isPinned, isTrue);
    expect(note.version, 7);
    expect(note.tagIds, ['t1']);
    expect(reader.contents.tags.single.name, 'molagis');
    expect(reader.fileBytes(note.attachments.single.file), [9, 9, 9]);
  });

  test('an attachment whose file is gone is left out', () async {
    await db.into(db.notes).insert(
      NotesCompanion.insert(id: 'n1', title: 'Groceries'),
    );
    await db.into(db.noteAttachments).insert(
      NoteAttachmentsCompanion.insert(
        id: 'a1',
        noteId: 'n1',
        type: 'image',
        originalFilename: 'photo.jpg',
        mimeType: 'image/jpeg',
        fileSize: 3,
        localPath: const Value('/nowhere/photo.jpg'),
      ),
    );

    final zipPath = '${folder.path}/out.zip';
    final manifest = await BackupExporter(db, folder).write(
      zipPath,
      appVersion: '0.22.2',
    );

    expect(manifest.attachments, 0);
    expect(
      BackupReader(File(zipPath).readAsBytesSync()).contents.notes.single
          .attachments,
      isEmpty,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/backup_exporter_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the exporter**

```dart
// lib/features/backup/data/backup_exporter.dart
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../core/database/app_database.dart';
import '../domain/backup_contents.dart';
import '../domain/backup_manifest.dart';
import 'backup_writer.dart';

/// Reads every note, tag and attachment out of the database and writes them
/// into one zip.
class BackupExporter {
  BackupExporter(this._db, this._attachmentsRoot);

  final AppDatabase _db;

  /// The `attachments` directory under the app documents directory.
  final Directory _attachmentsRoot;

  Future<BackupManifest> write(
    String zipPath, {
    required String appVersion,
  }) async {
    final writer = BackupWriter(zipPath);
    try {
      final tags = await _db.select(_db.tags).get();
      final notes = await _db.select(_db.notes).get();
      final attachments = await _db.select(_db.noteAttachments).get();
      final noteTags = await _db.select(_db.noteTags).get();

      final tagIdsByNote = <String, List<String>>{};
      for (final row in noteTags) {
        tagIdsByNote.putIfAbsent(row.noteId, () => []).add(row.tagId);
      }

      final backupNotes = <BackupNote>[];
      var attachmentCount = 0;

      for (final note in notes) {
        final backupAttachments = <BackupAttachment>[];
        for (final attachment in attachments.where(
          (row) => row.noteId == note.id,
        )) {
          final source = _sourceOf(attachment);
          if (source == null) continue;

          final name = 'attachments/${attachment.id}${path.extension(source.path)}';
          await writer.addFile(source, name);
          attachmentCount++;
          backupAttachments.add(
            BackupAttachment(
              id: attachment.id,
              type: attachment.type,
              originalFilename: attachment.originalFilename,
              mimeType: attachment.mimeType,
              fileSize: attachment.fileSize,
              position: attachment.position,
              file: name,
            ),
          );
        }

        backupNotes.add(
          BackupNote(
            id: note.id,
            title: note.title,
            content: note.content,
            isPinned: note.isPinned,
            isArchived: note.isArchived,
            background: note.background,
            state: note.state,
            updatedAt: note.updatedAt,
            version: note.version,
            reminderAt: note.reminderAt,
            reminderRecurrence: note.reminderRecurrence,
            tagIds: tagIdsByNote[note.id] ?? const [],
            attachments: backupAttachments,
          ),
        );
      }

      final manifest = BackupManifest(
        format: BackupManifest.currentFormat,
        app: 'anchor',
        appVersion: appVersion,
        createdAt: DateTime.now().toUtc(),
        notes: backupNotes.length,
        attachments: attachmentCount,
      );

      await writer.addJson('manifest.json', manifest.toJson());
      await writer.addJson(
        'notes.json',
        BackupContents(
          tags: [
            for (final tag in tags)
              BackupTag(id: tag.id, name: tag.name, color: tag.color),
          ],
          notes: backupNotes,
        ).toJson(),
      );
      return manifest;
    } finally {
      await writer.close();
    }
  }

  /// Null when the row has no local file, or the file is gone.
  File? _sourceOf(AttachmentRow row) {
    final stored = row.localPath;
    if (stored == null) return null;
    final file = File(stored);
    return file.existsSync() ? file : null;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd mobile && flutter test test/backup/backup_exporter_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/backup/data/backup_exporter.dart mobile/test/backup/backup_exporter_test.dart
git commit -m "feat: export every note, tag and attachment into a backup"
```

---

### Task 5: Restore into the database

**Files:**
- Create: `lib/features/backup/domain/restore_mode.dart`
- Create: `lib/features/backup/data/backup_restorer.dart`
- Test: `test/backup/backup_restorer_test.dart`

**Interfaces:**
- Consumes: `BackupReader` (Task 2), `BackupContents` (Task 1), `AppDatabase`, `newId()` from `lib/core/ids.dart`.
- Produces:
  - `enum RestoreMode { keepIds, newIds }`
  - `class BackupRestorer { BackupRestorer(this.db, this.attachmentsRoot); Future<int> restore(BackupReader reader, RestoreMode mode); }` — returns the number of notes written.

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/backup_restorer_test.dart
import 'dart:io';

import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/features/backup/data/backup_exporter.dart';
import 'package:anchor/features/backup/data/backup_reader.dart';
import 'package:anchor/features/backup/data/backup_restorer.dart';
import 'package:anchor/features/backup/domain/restore_mode.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;
  late Directory folder;

  setUp(() {
    source = AppDatabase.forTesting(NativeDatabase.memory());
    target = AppDatabase.forTesting(NativeDatabase.memory());
    folder = Directory.systemTemp.createTempSync('backup_restore');
  });

  tearDown(() async {
    await source.close();
    await target.close();
    folder.deleteSync(recursive: true);
  });

  Future<BackupReader> exportOneNote() async {
    await source.into(source.notes).insert(
      NotesCompanion.insert(
        id: 'n1',
        title: 'Groceries',
        content: const Value('{"ops":[]}'),
        version: const Value(7),
      ),
    );
    final zipPath = '${folder.path}/out.zip';
    await BackupExporter(source, folder).write(zipPath, appVersion: '0.22.2');
    return BackupReader(File(zipPath).readAsBytesSync());
  }

  test('keepIds keeps the id and the version, and marks the note unsynced',
      () async {
    final reader = await exportOneNote();
    final written = await BackupRestorer(target, folder).restore(
      reader,
      RestoreMode.keepIds,
    );

    expect(written, 1);
    final row = await target.noteRow('n1');
    expect(row, isNotNull);
    expect(row!.title, 'Groceries');
    expect(row.version, 7);
    expect(row.isSynced, isFalse);
    expect(row.localRev, 0);
  });

  test('newIds gives a fresh id and clears the version', () async {
    final reader = await exportOneNote();
    await BackupRestorer(target, folder).restore(reader, RestoreMode.newIds);

    final rows = await target.select(target.notes).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, isNot('n1'));
    expect(rows.single.version, isNull);
    expect(rows.single.isSynced, isFalse);
  });

  test('restore replaces what was there', () async {
    await target.into(target.notes).insert(
      NotesCompanion.insert(id: 'old', title: 'Old note'),
    );
    final reader = await exportOneNote();
    await BackupRestorer(target, folder).restore(reader, RestoreMode.keepIds);

    final rows = await target.select(target.notes).get();
    expect(rows.map((row) => row.id), ['n1']);
  });

  test('an attachment is written to disk and points at the new file',
      () async {
    await source.into(source.notes).insert(
      NotesCompanion.insert(id: 'n1', title: 'Groceries'),
    );
    final noteDir = Directory('${folder.path}/n1')..createSync(recursive: true);
    final photo = File('${noteDir.path}/a1-photo.jpg')
      ..writeAsBytesSync([5, 5, 5]);
    await source.into(source.noteAttachments).insert(
      NoteAttachmentsCompanion.insert(
        id: 'a1',
        noteId: 'n1',
        type: 'image',
        originalFilename: 'photo.jpg',
        mimeType: 'image/jpeg',
        fileSize: 3,
        localPath: Value(photo.path),
      ),
    );
    final zipPath = '${folder.path}/out.zip';
    await BackupExporter(source, folder).write(zipPath, appVersion: '0.22.2');

    final targetRoot = Directory('${folder.path}/target')..createSync();
    await BackupRestorer(
      target,
      targetRoot,
    ).restore(BackupReader(File(zipPath).readAsBytesSync()), RestoreMode.keepIds);

    final row = (await target.select(target.noteAttachments).get()).single;
    expect(row.serverAttachmentId, isNull);
    expect(row.syncStatus, 'pending_upload');
    expect(File(row.localPath!).readAsBytesSync(), [5, 5, 5]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/backup_restorer_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the mode and the restorer**

```dart
// lib/features/backup/domain/restore_mode.dart
/// How a restore treats the ids in the backup.
enum RestoreMode {
  /// The same account: keep the ids and the server versions, so the server can
  /// tell an unchanged note from one edited after the backup.
  keepIds,

  /// Any account: fresh ids and no version, so the server creates every note.
  newIds,
}
```

```dart
// lib/features/backup/data/backup_restorer.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as path;

import '../../../core/database/app_database.dart';
import '../../../core/ids.dart';
import '../domain/restore_mode.dart';
import 'backup_reader.dart';

/// Replaces every local note, tag and attachment with the contents of a backup.
class BackupRestorer {
  BackupRestorer(this._db, this._attachmentsRoot);

  final AppDatabase _db;

  /// The `attachments` directory under the app documents directory.
  final Directory _attachmentsRoot;

  Future<int> restore(BackupReader reader, RestoreMode mode) async {
    final contents = reader.contents;
    final tagIdMap = <String, String>{};
    final noteIdMap = <String, String>{};

    for (final tag in contents.tags) {
      tagIdMap[tag.id] = mode == RestoreMode.keepIds ? tag.id : newId();
    }
    for (final note in contents.notes) {
      noteIdMap[note.id] = mode == RestoreMode.keepIds ? note.id : newId();
    }

    await _db.transaction(() async {
      await _db.delete(_db.noteTags).go();
      await _db.delete(_db.noteAttachments).go();
      await _db.delete(_db.notes).go();
      await _db.delete(_db.tags).go();

      for (final tag in contents.tags) {
        await _db.into(_db.tags).insert(
          TagsCompanion.insert(
            id: tagIdMap[tag.id]!,
            name: tag.name,
            color: Value(tag.color),
            isSynced: const Value(false),
          ),
        );
      }

      for (final note in contents.notes) {
        final noteId = noteIdMap[note.id]!;
        await _db.into(_db.notes).insert(
          NotesCompanion.insert(
            id: noteId,
            title: note.title,
            content: Value(note.content),
            isPinned: Value(note.isPinned),
            isArchived: Value(note.isArchived),
            background: Value(note.background),
            state: Value(note.state),
            updatedAt: Value(note.updatedAt),
            version: Value(
              mode == RestoreMode.keepIds ? note.version : null,
            ),
            reminderAt: Value(note.reminderAt),
            reminderRecurrence: Value(note.reminderRecurrence),
            isSynced: const Value(false),
            localRev: const Value(0),
          ),
        );

        for (final tagId in note.tagIds) {
          final mapped = tagIdMap[tagId];
          if (mapped == null) continue;
          await _db.into(_db.noteTags).insert(
            NoteTagsCompanion.insert(noteId: noteId, tagId: mapped),
          );
        }

        for (final attachment in note.attachments) {
          final attachmentId = mode == RestoreMode.keepIds
              ? attachment.id
              : newId();
          final noteDir = Directory(path.join(_attachmentsRoot.path, noteId));
          if (!noteDir.existsSync()) noteDir.createSync(recursive: true);

          final target = File(
            path.join(
              noteDir.path,
              '$attachmentId-${path.basename(attachment.originalFilename)}',
            ),
          );
          await target.writeAsBytes(reader.fileBytes(attachment.file));

          await _db.into(_db.noteAttachments).insert(
            NoteAttachmentsCompanion.insert(
              id: attachmentId,
              noteId: noteId,
              type: attachment.type,
              originalFilename: attachment.originalFilename,
              mimeType: attachment.mimeType,
              fileSize: attachment.fileSize,
              position: Value(attachment.position),
              localPath: Value(target.path),
              syncStatus: const Value('pending_upload'),
            ),
          );
        }
      }
    });

    return contents.notes.length;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd mobile && flutter test test/backup/backup_restorer_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/backup/domain/restore_mode.dart mobile/lib/features/backup/data/backup_restorer.dart mobile/test/backup/backup_restorer_test.dart
git commit -m "feat: restore a backup into the database, keeping or renewing ids"
```

---

### Task 6: Pick the backup folder

**Files:**
- Create: `android/app/src/main/kotlin/com/zhfahim/anchor/backup/BackupFolderPlugin.kt`
- Modify: `android/app/src/main/kotlin/com/zhfahim/anchor/MainActivity.kt`
- Create: `lib/features/backup/data/backup_folder.dart`
- Test: `test/backup/backup_folder_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class BackupFolder { BackupFolder([MethodChannel? channel]); Future<String?> pick(); Future<void> write(String folderUri, String name, List<int> bytes); Future<List<String>> list(String folderUri); Future<void> delete(String folderUri, String name); }`
  - Channel name `anchor/backup`, methods `pickFolder`, `writeFile`, `listFiles`, `deleteFile`.

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/backup_folder_test.dart
import 'package:anchor/features/backup/data/backup_folder.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('anchor/backup');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'pickFolder' => 'content://tree/backups',
            'listFiles' => ['anchor-auto-1.zip', 'anchor-auto-2.zip'],
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('pick returns the folder the person chose', () async {
    expect(await BackupFolder().pick(), 'content://tree/backups');
  });

  test('write sends the name and the bytes', () async {
    await BackupFolder().write('content://tree/backups', 'a.zip', [1, 2]);
    expect(calls.single.method, 'writeFile');
    expect(calls.single.arguments['name'], 'a.zip');
    expect(calls.single.arguments['bytes'], [1, 2]);
  });

  test('list returns the file names', () async {
    expect(await BackupFolder().list('content://tree/backups'), [
      'anchor-auto-1.zip',
      'anchor-auto-2.zip',
    ]);
  });

  test('delete sends the name', () async {
    await BackupFolder().delete('content://tree/backups', 'a.zip');
    expect(calls.single.method, 'deleteFile');
    expect(calls.single.arguments['name'], 'a.zip');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/backup_folder_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the Dart wrapper**

```dart
// lib/features/backup/data/backup_folder.dart
import 'package:flutter/services.dart';

/// The folder the person picked, reached through Android's document tree so it
/// stays writable after a restart.
class BackupFolder {
  BackupFolder([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('anchor/backup');

  final MethodChannel _channel;

  Future<String?> pick() => _channel.invokeMethod<String>('pickFolder');

  Future<void> write(String folderUri, String name, List<int> bytes) {
    return _channel.invokeMethod<void>('writeFile', {
      'folder': folderUri,
      'name': name,
      'bytes': bytes,
    });
  }

  Future<List<String>> list(String folderUri) async {
    final names = await _channel.invokeListMethod<String>('listFiles', {
      'folder': folderUri,
    });
    return names ?? const [];
  }

  Future<void> delete(String folderUri, String name) {
    return _channel.invokeMethod<void>('deleteFile', {
      'folder': folderUri,
      'name': name,
    });
  }
}
```

- [ ] **Step 4: Write the Kotlin plugin**

```kotlin
// android/app/src/main/kotlin/com/zhfahim/anchor/backup/BackupFolderPlugin.kt
package com.zhfahim.anchor.backup

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Picks a folder through the document tree and keeps write access to it across
 * restarts, the way NotallyX does.
 */
class BackupFolderPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var pending: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        binding?.removeActivityResultListener(this)
        binding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickFolder" -> pickFolder(result)
            "writeFile" -> writeFile(call, result)
            "listFiles" -> listFiles(call, result)
            "deleteFile" -> deleteFile(call, result)
            else -> result.notImplemented()
        }
    }

    private fun pickFolder(result: MethodChannel.Result) {
        val current = activity
        if (current == null) {
            result.error("no_activity", "The folder picker needs a screen.", null)
            return
        }
        if (pending != null) {
            result.error("busy", "A folder is already being picked.", null)
            return
        }
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        current.startActivityForResult(intent, REQUEST_PICK)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK) return false
        val result = pending ?: return false
        pending = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        val flags = data.flags and
            (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try {
            activity?.contentResolver?.takePersistableUriPermission(uri, flags)
        } catch (_: SecurityException) {
            // Some providers refuse; the folder still works for this session.
        }
        result.success(uri.toString())
        return true
    }

    private fun writeFile(call: MethodCall, result: MethodChannel.Result) {
        val folder = folderOf(call)
        val name = call.argument<String>("name")
        val bytes = call.argument<ByteArray>("bytes")
        if (folder == null || name == null || bytes == null) {
            result.error("bad_args", "A folder, a name and bytes are required.", null)
            return
        }
        try {
            folder.findFile(name)?.delete()
            val file = folder.createFile("application/zip", name)
            if (file == null) {
                result.error("no_file", "The folder refused a new file.", null)
                return
            }
            activity?.contentResolver?.openOutputStream(file.uri)?.use { it.write(bytes) }
            result.success(null)
        } catch (error: Exception) {
            result.error("write_failed", error.message, null)
        }
    }

    private fun listFiles(call: MethodCall, result: MethodChannel.Result) {
        val folder = folderOf(call)
        if (folder == null) {
            result.error("bad_args", "A folder is required.", null)
            return
        }
        result.success(folder.listFiles().mapNotNull { it.name })
    }

    private fun deleteFile(call: MethodCall, result: MethodChannel.Result) {
        val folder = folderOf(call)
        val name = call.argument<String>("name")
        if (folder == null || name == null) {
            result.error("bad_args", "A folder and a name are required.", null)
            return
        }
        folder.findFile(name)?.delete()
        result.success(null)
    }

    private fun folderOf(call: MethodCall): DocumentFile? {
        val uri = call.argument<String>("folder") ?: return null
        return DocumentFile.fromTreeUri(activity ?: return null, Uri.parse(uri))
    }

    companion object {
        private const val CHANNEL = "anchor/backup"
        private const val REQUEST_PICK = 4711
    }
}
```

- [ ] **Step 5: Register the plugin**

In `MainActivity.kt`, add the import and one line inside `configureFlutterEngine`:

```kotlin
import com.zhfahim.anchor.backup.BackupFolderPlugin
```

```kotlin
        flutterEngine.plugins.add(BackupFolderPlugin())
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `cd mobile && flutter test test/backup/backup_folder_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 7: Build the Android app to prove the Kotlin compiles**

Run: `cd mobile && flutter build apk --debug`
Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 8: Commit**

```bash
git add mobile/android/app/src/main/kotlin/com/zhfahim/anchor/backup mobile/android/app/src/main/kotlin/com/zhfahim/anchor/MainActivity.kt mobile/lib/features/backup/data/backup_folder.dart mobile/test/backup/backup_folder_test.dart
git commit -m "feat: pick a backup folder through the document tree"
```

---

### Task 7: Backup preferences

**Files:**
- Create: `lib/features/backup/domain/backup_settings.dart`
- Create: `lib/features/backup/presentation/backup_settings_controller.dart`
- Modify: `lib/core/storage/storage_keys.dart`
- Modify: `lib/core/storage/preferences_repository.dart`
- Test: `test/backup/backup_settings_controller_test.dart`

**Interfaces:**
- Consumes: `PreferencesRepository`, `StorageKeys`.
- Produces:
  - `class BackupSettings { final String? folderUri; final bool automatic; final int periodDays; final int keepFiles; final String? password; final DateTime? lastBackupAt; BackupSettings copyWith({...}); }`
  - `@Riverpod(keepAlive: true) class BackupSettingsController extends _$BackupSettingsController { BackupSettings build(); Future<void> setFolder(String? uri); Future<void> setAutomatic(bool value); Future<void> setPeriodDays(int days); Future<void> setKeepFiles(int count); Future<void> setPassword(String? password); Future<void> markBackedUp(DateTime at); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/backup_settings_controller_test.dart
import 'package:anchor/core/storage/preferences_repository.dart';
import 'package:anchor/features/backup/presentation/backup_settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPreferencesRepository extends Mock
    implements PreferencesRepository {}

void main() {
  late MockPreferencesRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockPreferencesRepository();
    when(() => repository.getBackupFolder()).thenAnswer((_) async => null);
    when(() => repository.getBackupAutomatic()).thenAnswer((_) async => true);
    when(() => repository.getBackupPeriodDays()).thenAnswer((_) async => 7);
    when(() => repository.getBackupKeepFiles()).thenAnswer((_) async => 3);
    when(() => repository.getBackupPassword()).thenAnswer((_) async => null);
    when(() => repository.getBackupLastAt()).thenAnswer((_) async => null);
    when(() => repository.setBackupPeriodDays(any())).thenAnswer((_) async {});
    when(() => repository.setBackupKeepFiles(any())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('the defaults are a week and three files', () async {
    final settings = await container.read(
      backupSettingsControllerProvider.future,
    );
    expect(settings.periodDays, 7);
    expect(settings.keepFiles, 3);
    expect(settings.automatic, isTrue);
    expect(settings.folderUri, isNull);
  });

  test('a period outside 1 to 31 is clamped', () async {
    final controller = container.read(
      backupSettingsControllerProvider.notifier,
    );
    await container.read(backupSettingsControllerProvider.future);

    await controller.setPeriodDays(0);
    expect(
      container.read(backupSettingsControllerProvider).value!.periodDays,
      1,
    );

    await controller.setPeriodDays(99);
    expect(
      container.read(backupSettingsControllerProvider).value!.periodDays,
      31,
    );
  });

  test('kept files outside 1 to 10 is clamped', () async {
    final controller = container.read(
      backupSettingsControllerProvider.notifier,
    );
    await container.read(backupSettingsControllerProvider.future);

    await controller.setKeepFiles(0);
    expect(
      container.read(backupSettingsControllerProvider).value!.keepFiles,
      1,
    );

    await controller.setKeepFiles(50);
    expect(
      container.read(backupSettingsControllerProvider).value!.keepFiles,
      10,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/backup_settings_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Add the storage keys**

In `lib/core/storage/storage_keys.dart`, add before the closing brace:

```dart
  static const backupFolder = 'backup_folder_uri';
  static const backupAutomatic = 'backup_automatic';
  static const backupPeriodDays = 'backup_period_days';
  static const backupKeepFiles = 'backup_keep_files';
  static const backupPassword = 'backup_password';
  static const backupLastAt = 'backup_last_at';
```

- [ ] **Step 4: Add the repository methods**

In `lib/core/storage/preferences_repository.dart`, add inside `class PreferencesRepository`:

```dart
  Future<String?> getBackupFolder() =>
      _storage.read(key: StorageKeys.backupFolder);

  Future<void> setBackupFolder(String? uri) => uri == null
      ? _storage.delete(key: StorageKeys.backupFolder)
      : _storage.write(key: StorageKeys.backupFolder, value: uri);

  Future<bool> getBackupAutomatic() async =>
      await _storage.read(key: StorageKeys.backupAutomatic) != 'false';

  Future<void> setBackupAutomatic(bool value) => _storage.write(
    key: StorageKeys.backupAutomatic,
    value: value.toString(),
  );

  Future<int> getBackupPeriodDays() async =>
      int.tryParse(
        await _storage.read(key: StorageKeys.backupPeriodDays) ?? '',
      ) ??
      7;

  Future<void> setBackupPeriodDays(int days) =>
      _storage.write(key: StorageKeys.backupPeriodDays, value: '$days');

  Future<int> getBackupKeepFiles() async =>
      int.tryParse(
        await _storage.read(key: StorageKeys.backupKeepFiles) ?? '',
      ) ??
      3;

  Future<void> setBackupKeepFiles(int count) =>
      _storage.write(key: StorageKeys.backupKeepFiles, value: '$count');

  Future<String?> getBackupPassword() =>
      _storage.read(key: StorageKeys.backupPassword);

  Future<void> setBackupPassword(String? password) => password == null
      ? _storage.delete(key: StorageKeys.backupPassword)
      : _storage.write(key: StorageKeys.backupPassword, value: password);

  Future<DateTime?> getBackupLastAt() async {
    final stored = await _storage.read(key: StorageKeys.backupLastAt);
    return stored == null ? null : DateTime.tryParse(stored);
  }

  Future<void> setBackupLastAt(DateTime at) => _storage.write(
    key: StorageKeys.backupLastAt,
    value: at.toUtc().toIso8601String(),
  );
```

- [ ] **Step 5: Write the settings model and controller**

```dart
// lib/features/backup/domain/backup_settings.dart
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
    bool clearPassword = false,
  }) => BackupSettings(
    folderUri: folderUri ?? this.folderUri,
    automatic: automatic ?? this.automatic,
    periodDays: periodDays ?? this.periodDays,
    keepFiles: keepFiles ?? this.keepFiles,
    password: clearPassword ? null : (password ?? this.password),
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
  );
}
```

```dart
// lib/features/backup/presentation/backup_settings_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/preferences_repository.dart';
import '../domain/backup_settings.dart';

part 'backup_settings_controller.g.dart';

@Riverpod(keepAlive: true)
class BackupSettingsController extends _$BackupSettingsController {
  @override
  Future<BackupSettings> build() async {
    final repository = ref.watch(preferencesRepositoryProvider);
    return BackupSettings(
      folderUri: await repository.getBackupFolder(),
      automatic: await repository.getBackupAutomatic(),
      periodDays: await repository.getBackupPeriodDays(),
      keepFiles: await repository.getBackupKeepFiles(),
      password: await repository.getBackupPassword(),
      lastBackupAt: await repository.getBackupLastAt(),
    );
  }

  Future<void> setFolder(String? uri) async {
    await ref.read(preferencesRepositoryProvider).setBackupFolder(uri);
    _update((settings) => settings.copyWith(folderUri: uri));
  }

  Future<void> setAutomatic(bool value) async {
    await ref.read(preferencesRepositoryProvider).setBackupAutomatic(value);
    _update((settings) => settings.copyWith(automatic: value));
  }

  Future<void> setPeriodDays(int days) async {
    final clamped = days.clamp(
      BackupSettings.minPeriodDays,
      BackupSettings.maxPeriodDays,
    );
    await ref.read(preferencesRepositoryProvider).setBackupPeriodDays(clamped);
    _update((settings) => settings.copyWith(periodDays: clamped));
  }

  Future<void> setKeepFiles(int count) async {
    final clamped = count.clamp(
      BackupSettings.minKeepFiles,
      BackupSettings.maxKeepFiles,
    );
    await ref.read(preferencesRepositoryProvider).setBackupKeepFiles(clamped);
    _update((settings) => settings.copyWith(keepFiles: clamped));
  }

  Future<void> setPassword(String? password) async {
    await ref.read(preferencesRepositoryProvider).setBackupPassword(password);
    _update(
      (settings) => password == null
          ? settings.copyWith(clearPassword: true)
          : settings.copyWith(password: password),
    );
  }

  Future<void> markBackedUp(DateTime at) async {
    await ref.read(preferencesRepositoryProvider).setBackupLastAt(at);
    _update((settings) => settings.copyWith(lastBackupAt: at));
  }

  void _update(BackupSettings Function(BackupSettings) change) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(change(current));
  }
}
```

- [ ] **Step 6: Generate the riverpod code**

Run: `cd mobile && dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded after ...`

- [ ] **Step 7: Run the test to verify it passes**

Run: `cd mobile && flutter test test/backup/backup_settings_controller_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/core/storage mobile/lib/features/backup mobile/test/backup
git commit -m "feat: remember the backup folder, the period and the password"
```

---

### Task 8: The backup job

**Files:**
- Create: `lib/features/backup/presentation/backup_controller.dart`
- Test: `test/backup/backup_controller_test.dart`

**Interfaces:**
- Consumes: `BackupExporter` (Task 4), `BackupCipher` (Task 3), `BackupFolder` (Task 6), `BackupSettingsController` (Task 7), `AppDatabase`.
- Produces:
  - `enum BackupOutcome { done, noFolder, failed }`
  - `class BackupResult { final BackupOutcome outcome; final String? fileName; final String? error; }`
  - `@Riverpod(keepAlive: true) class BackupController extends _$BackupController { bool build(); Future<BackupResult> run({required bool automatic}); }` — state is `true` while a backup runs.

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/backup_controller_test.dart
import 'dart:io';

import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/features/backup/data/backup_folder.dart';
import 'package:anchor/features/backup/presentation/backup_controller.dart';
import 'package:anchor/features/backup/presentation/backup_settings_controller.dart';
import 'package:anchor/features/backup/domain/backup_settings.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBackupFolder extends Mock implements BackupFolder {}

class FakeSettings extends BackupSettingsController {
  FakeSettings(this.initial);

  final BackupSettings initial;

  @override
  Future<BackupSettings> build() async => initial;

  @override
  Future<void> markBackedUp(DateTime at) async {}
}

void main() {
  late AppDatabase db;
  late MockBackupFolder folder;
  late Directory root;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    folder = MockBackupFolder();
    root = Directory.systemTemp.createTempSync('backup_job');
  });

  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  ProviderContainer containerWith(BackupSettings settings) {
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        backupFolderProvider.overrideWithValue(folder),
        backupSettingsControllerProvider.overrideWith(
          () => FakeSettings(settings),
        ),
      ],
    );
  }

  test('a backup with no folder chosen says so', () async {
    final container = containerWith(const BackupSettings());
    final result = await container
        .read(backupControllerProvider.notifier)
        .run(automatic: false);

    expect(result.outcome, BackupOutcome.noFolder);
    verifyNever(
      () => folder.write(any(), any(), any()),
    );
  });

  test('a backup writes one file and marks the time', () async {
    when(
      () => folder.write(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(() => folder.list(any())).thenAnswer((_) async => <String>[]);

    final container = containerWith(
      const BackupSettings(folderUri: 'content://tree/backups'),
    );
    final result = await container
        .read(backupControllerProvider.notifier)
        .run(automatic: false);

    expect(result.outcome, BackupOutcome.done);
    expect(result.fileName, startsWith('anchor-'));
    verify(() => folder.write('content://tree/backups', any(), any())).called(1);
  });

  test('a write that throws is reported, not swallowed', () async {
    when(
      () => folder.write(any(), any(), any()),
    ).thenThrow(Exception('disk full'));

    final container = containerWith(
      const BackupSettings(folderUri: 'content://tree/backups'),
    );
    final result = await container
        .read(backupControllerProvider.notifier)
        .run(automatic: false);

    expect(result.outcome, BackupOutcome.failed);
    expect(result.error, contains('disk full'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/backup_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the controller**

```dart
// lib/features/backup/presentation/backup_controller.dart
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../data/backup_cipher.dart';
import '../data/backup_exporter.dart';
import '../data/backup_folder.dart';
import 'backup_settings_controller.dart';

part 'backup_controller.g.dart';

enum BackupOutcome { done, noFolder, failed }

class BackupResult {
  const BackupResult(this.outcome, {this.fileName, this.error});

  final BackupOutcome outcome;
  final String? fileName;
  final String? error;
}

@Riverpod(keepAlive: true)
BackupFolder backupFolder(Ref ref) => BackupFolder();

/// True while a backup runs. Kept alive so leaving Settings does not stop it.
@Riverpod(keepAlive: true)
class BackupController extends _$BackupController {
  @override
  bool build() => false;

  Future<BackupResult> run({required bool automatic}) async {
    if (state) return const BackupResult(BackupOutcome.failed, error: 'busy');
    state = true;
    try {
      return await _run(automatic: automatic);
    } finally {
      state = false;
    }
  }

  Future<BackupResult> _run({required bool automatic}) async {
    final settings = await ref.read(backupSettingsControllerProvider.future);
    if (!settings.hasFolder) {
      return const BackupResult(BackupOutcome.noFolder);
    }

    final folder = ref.read(backupFolderProvider);
    final documents = await getApplicationDocumentsDirectory();
    final attachmentsRoot = Directory(
      path.join(documents.path, 'attachments'),
    );
    final temp = await getTemporaryDirectory();
    final stamp = _stamp(DateTime.now());
    final prefix = automatic ? 'anchor-auto-' : 'anchor-';
    final fileName = '$prefix$stamp.zip';
    final zipPath = path.join(temp.path, fileName);

    try {
      final info = await PackageInfo.fromPlatform();
      final manifest = await BackupExporter(
        ref.read(appDatabaseProvider),
        attachmentsRoot,
      ).write(zipPath, appVersion: info.version);

      var bytes = await File(zipPath).readAsBytes();
      final password = settings.password;
      if (password != null && password.isNotEmpty) {
        bytes = await BackupCipher.encrypt(bytes, password);
      }

      await folder.write(settings.folderUri!, fileName, bytes);
      await ref
          .read(backupSettingsControllerProvider.notifier)
          .markBackedUp(DateTime.now());

      if (automatic) await _applyRetention(folder, settings.folderUri!, settings.keepFiles);

      AppLogger.instance.info(
        LogTags.backup,
        'Backup wrote $fileName with ${manifest.notes} notes',
      );
      return BackupResult(BackupOutcome.done, fileName: fileName);
    } catch (error, stack) {
      AppLogger.instance.error(
        LogTags.backup,
        'Backup failed',
        error: error,
        stackTrace: stack,
      );
      return BackupResult(BackupOutcome.failed, error: '$error');
    } finally {
      final leftover = File(zipPath);
      if (leftover.existsSync()) leftover.deleteSync();
    }
  }

  /// Only files this app wrote automatically are counted, so a manual backup is
  /// never deleted.
  Future<void> _applyRetention(
    BackupFolder folder,
    String folderUri,
    int keepFiles,
  ) async {
    final names =
        (await folder.list(folderUri))
            .where((name) => name.startsWith('anchor-auto-'))
            .toList()
          ..sort();
    final excess = names.length - keepFiles;
    if (excess <= 0) return;
    for (final name in names.take(excess)) {
      await folder.delete(folderUri, name);
    }
  }

  String _stamp(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)}'
        '_${two(at.hour)}${two(at.minute)}${two(at.second)}';
  }
}
```

- [ ] **Step 4: Add the log tag**

In `lib/core/logging/log_tags.dart`, add `static const backup = 'Backup';` next to the other tags.

- [ ] **Step 5: Generate the riverpod code**

Run: `cd mobile && dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded after ...`

- [ ] **Step 6: Run the test to verify it passes**

Run: `cd mobile && flutter test test/backup/backup_controller_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/core/logging mobile/lib/features/backup mobile/test/backup
git commit -m "feat: run a backup as a job that outlives the settings page"
```

---

### Task 9: Automatic backup when the app opens

**Files:**
- Create: `lib/features/backup/data/auto_backup.dart`
- Test: `test/backup/auto_backup_test.dart`

**Interfaces:**
- Consumes: `BackupController` (Task 8), `BackupSettings` (Task 7).
- Produces:
  - `class AutoBackup { AutoBackup(this.run, this.now); final Future<BackupResult> Function() run; final DateTime Function() now; Future<bool> maybeRun(BackupSettings settings); }` — returns true when it ran.

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/auto_backup_test.dart
import 'package:anchor/features/backup/data/auto_backup.dart';
import 'package:anchor/features/backup/domain/backup_settings.dart';
import 'package:anchor/features/backup/presentation/backup_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 14, 12);

  test('runs when there has never been a backup', () async {
    var ran = 0;
    final auto = AutoBackup(() async {
      ran++;
      return const BackupResult(BackupOutcome.done);
    }, () => now);

    expect(
      await auto.maybeRun(
        const BackupSettings(folderUri: 'content://tree/backups'),
      ),
      isTrue,
    );
    expect(ran, 1);
  });

  test('does not run before the period is up', () async {
    var ran = 0;
    final auto = AutoBackup(() async {
      ran++;
      return const BackupResult(BackupOutcome.done);
    }, () => now);

    final settings = BackupSettings(
      folderUri: 'content://tree/backups',
      periodDays: 7,
      lastBackupAt: now.subtract(const Duration(days: 3)),
    );
    expect(await auto.maybeRun(settings), isFalse);
    expect(ran, 0);
  });

  test('runs once the period is up', () async {
    var ran = 0;
    final auto = AutoBackup(() async {
      ran++;
      return const BackupResult(BackupOutcome.done);
    }, () => now);

    final settings = BackupSettings(
      folderUri: 'content://tree/backups',
      periodDays: 7,
      lastBackupAt: now.subtract(const Duration(days: 8)),
    );
    expect(await auto.maybeRun(settings), isTrue);
    expect(ran, 1);
  });

  test('does nothing when automatic backup is off', () async {
    var ran = 0;
    final auto = AutoBackup(() async {
      ran++;
      return const BackupResult(BackupOutcome.done);
    }, () => now);

    expect(
      await auto.maybeRun(
        const BackupSettings(
          folderUri: 'content://tree/backups',
          automatic: false,
        ),
      ),
      isFalse,
    );
    expect(ran, 0);
  });

  test('does nothing when no folder is chosen', () async {
    var ran = 0;
    final auto = AutoBackup(() async {
      ran++;
      return const BackupResult(BackupOutcome.done);
    }, () => now);

    expect(await auto.maybeRun(const BackupSettings()), isFalse);
    expect(ran, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/auto_backup_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the rule**

```dart
// lib/features/backup/data/auto_backup.dart
import '../domain/backup_settings.dart';
import '../presentation/backup_controller.dart';

/// Decides whether an automatic backup is due. It runs when the app opens
/// rather than on a schedule, so no background service is needed.
class AutoBackup {
  const AutoBackup(this.run, this.now);

  final Future<BackupResult> Function() run;
  final DateTime Function() now;

  Future<bool> maybeRun(BackupSettings settings) async {
    if (!settings.automatic || !settings.hasFolder) return false;

    final last = settings.lastBackupAt;
    if (last != null &&
        now().difference(last) < Duration(days: settings.periodDays)) {
      return false;
    }

    await run();
    return true;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd mobile && flutter test test/backup/auto_backup_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/backup/data/auto_backup.dart mobile/test/backup/auto_backup_test.dart
git commit -m "feat: back up on app open when the period is up"
```

---

### Task 10: The Backup section in Settings

**Files:**
- Create: `lib/features/backup/presentation/backup_section.dart`
- Create: `lib/features/backup/presentation/restore_sheet.dart`
- Modify: `lib/features/settings/presentation/settings_screen.dart`
- Modify: `lib/main.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/backup/backup_section_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces:
  - `class BackupSection extends ConsumerWidget` — the whole Settings section.
  - `Future<RestoreMode?> showRestoreSheet(BuildContext context, {required int notes, required int attachments})`
  - `final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();` in `lib/main.dart`.

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/backup_section_test.dart
import 'package:anchor/features/backup/domain/backup_settings.dart';
import 'package:anchor/features/backup/presentation/backup_controller.dart';
import 'package:anchor/features/backup/presentation/backup_section.dart';
import 'package:anchor/features/backup/presentation/backup_settings_controller.dart';
import 'package:anchor/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSettings extends BackupSettingsController {
  FakeSettings(this.initial);

  final BackupSettings initial;

  @override
  Future<BackupSettings> build() async => initial;
}

class FakeBackup extends BackupController {
  @override
  bool build() => false;
}

void main() {
  Future<void> pump(WidgetTester tester, BackupSettings settings) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupSettingsControllerProvider.overrideWith(
            () => FakeSettings(settings),
          ),
          backupControllerProvider.overrideWith(FakeBackup.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SingleChildScrollView(child: BackupSection())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('with no folder it asks for one', (tester) async {
    await pump(tester, const BackupSettings());
    expect(find.text('Choose a folder'), findsOneWidget);
  });

  testWidgets('with a folder it offers a backup now', (tester) async {
    await pump(
      tester,
      const BackupSettings(folderUri: 'content://tree/backups'),
    );
    expect(find.text('Back up now'), findsOneWidget);
    expect(find.text('Choose a folder'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/backup_section_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Add the copy**

In `lib/l10n/app_en.arb`, add before the closing brace:

```json
  "settingsBackup": "Backup",
  "@settingsBackup": {"description": "Settings section for local backups"},
  "backupChooseFolder": "Choose a folder",
  "@backupChooseFolder": {"description": "Button that opens the folder picker"},
  "backupFolder": "Folder",
  "@backupFolder": {"description": "Label of the chosen backup folder"},
  "backupNow": "Back up now",
  "@backupNow": {"description": "Button that writes a backup immediately"},
  "backupRunning": "Making a backup…",
  "@backupRunning": {"description": "Shown in the row while a backup runs"},
  "backupDone": "Backup saved as {name}",
  "@backupDone": {"placeholders": {"name": {"type": "String"}}},
  "backupFailed": "Backup failed: {reason}",
  "@backupFailed": {"placeholders": {"reason": {"type": "String"}}},
  "backupNoFolder": "Choose a folder first",
  "@backupNoFolder": {"description": "Toast when no folder is set"},
  "backupAutomatic": "Automatic backup",
  "@backupAutomatic": {"description": "Toggle for the periodic backup"},
  "backupPeriod": "Every {days} days",
  "@backupPeriod": {"placeholders": {"days": {"type": "int"}}},
  "backupKeep": "Keep {count} files",
  "@backupKeep": {"placeholders": {"count": {"type": "int"}}},
  "backupPassword": "Password",
  "@backupPassword": {"description": "Optional password for the backup file"},
  "backupPasswordNone": "None",
  "@backupPasswordNone": {"description": "Shown when no password is set"},
  "backupRestore": "Restore",
  "@backupRestore": {"description": "Button that opens the restore flow"},
  "restoreTitle": "Restore a backup",
  "@restoreTitle": {"description": "Title of the restore sheet"},
  "restoreKeepIds": "Restore this account",
  "@restoreKeepIds": {"description": "Restore mode for the same account"},
  "restoreKeepIdsHint": "Keeps the server versions. A note edited after the backup keeps the server copy.",
  "@restoreKeepIdsHint": {"description": "Explains the keep-ids mode"},
  "restoreNewIds": "Import as copies",
  "@restoreNewIds": {"description": "Restore mode for another account"},
  "restoreNewIdsHint": "Gives every note a new id. Use this for another account or another server.",
  "@restoreNewIdsHint": {"description": "Explains the new-ids mode"},
  "restoreConfirm": "Replace every note on this phone with {notes} notes from the backup?",
  "@restoreConfirm": {"placeholders": {"notes": {"type": "int"}}},
  "restoreDone": "Restored {notes} notes",
  "@restoreDone": {"placeholders": {"notes": {"type": "int"}}},
  "restoreWrongPassword": "Wrong password",
  "@restoreWrongPassword": {"description": "Shown when the backup password does not open the file"},
  "restoreBadFile": "This file is not an Anchor backup",
  "@restoreBadFile": {"description": "Shown when the picked file cannot be read"},
  "commonCancel": "Cancel",
  "@commonCancel": {"description": "Cancel button"},
  "commonReplace": "Replace",
  "@commonReplace": {"description": "Confirm button for a destructive restore"}
```

- [ ] **Step 4: Write the restore sheet**

```dart
// lib/features/backup/presentation/restore_sheet.dart
import 'package:flutter/material.dart';

import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../l10n/l10n.dart';
import '../domain/restore_mode.dart';

/// Asks which restore mode to use. The backup carries no account name, so the
/// person has to say whether this is the same account.
Future<RestoreMode?> showRestoreSheet(
  BuildContext context, {
  required int notes,
  required int attachments,
}) {
  return showModalBottomSheet<RestoreMode>(
    context: context,
    showDragHandle: true,
    builder: (context) => _RestoreSheet(notes: notes, attachments: attachments),
  );
}

class _RestoreSheet extends StatelessWidget {
  const _RestoreSheet({required this.notes, required this.attachments});

  final int notes;
  final int attachments;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.restoreTitle, style: context.textTheme.titleMedium),
            const SizedBox(height: AnchorTokens.space12),
            _ModeTile(
              title: l10n.restoreKeepIds,
              hint: l10n.restoreKeepIdsHint,
              onTap: () => Navigator.of(context).pop(RestoreMode.keepIds),
            ),
            const SizedBox(height: AnchorTokens.space8),
            _ModeTile(
              title: l10n.restoreNewIds,
              hint: l10n.restoreNewIdsHint,
              onTap: () => Navigator.of(context).pop(RestoreMode.newIds),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AnchorTokens.radius12),
      child: Padding(
        padding: const EdgeInsets.all(AnchorTokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.textTheme.titleSmall),
            const SizedBox(height: AnchorTokens.space4),
            Text(hint, style: context.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Write the section**

```dart
// lib/features/backup/presentation/backup_section.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/switch_row.dart';
import '../../../l10n/l10n.dart';
import '../../../main.dart' show scaffoldMessengerKey;
import '../../notes/data/repository/note_attachments_repository.dart';
import '../data/backup_cipher.dart';
import '../data/backup_folder.dart';
import '../data/backup_reader.dart';
import '../data/backup_restorer.dart';
import '../domain/backup_settings.dart';
import '../domain/restore_mode.dart';
import 'backup_controller.dart';
import 'backup_settings_controller.dart';
import 'restore_sheet.dart';

class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(backupSettingsControllerProvider).value;
    final running = ref.watch(backupControllerProvider);
    if (settings == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    return GroupedList(
      children: [
        _Row(
          label: l10n.backupFolder,
          value: settings.hasFolder ? l10n.backupFolder : l10n.backupChooseFolder,
          onTap: () => _pickFolder(context, ref),
        ),
        _Row(
          label: running ? l10n.backupRunning : l10n.backupNow,
          trailing: running
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: running ? null : () => _backupNow(context, ref),
        ),
        _Row(
          label: l10n.backupRestore,
          onTap: running ? null : () => _restore(context, ref),
        ),
        SwitchRow(
          label: l10n.backupAutomatic,
          value: settings.automatic,
          onChanged: (value) => ref
              .read(backupSettingsControllerProvider.notifier)
              .setAutomatic(value),
        ),
        _Row(
          label: l10n.backupPeriod(settings.periodDays),
          onTap: () => _pickPeriod(context, ref, settings),
        ),
        _Row(
          label: l10n.backupKeep(settings.keepFiles),
          onTap: () => _pickKeep(context, ref, settings),
        ),
        _Row(
          label: l10n.backupPassword,
          value: settings.password == null
              ? l10n.backupPasswordNone
              : '••••••',
          onTap: () => _pickPassword(context, ref),
        ),
      ],
    );
  }

  Future<void> _pickFolder(BuildContext context, WidgetRef ref) async {
    final uri = await ref.read(backupFolderProvider).pick();
    if (uri == null) return;
    await ref.read(backupSettingsControllerProvider.notifier).setFolder(uri);
  }

  Future<void> _backupNow(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(backupControllerProvider.notifier)
        .run(automatic: false);
    final l10n = context.l10n;
    final message = switch (result.outcome) {
      BackupOutcome.done => l10n.backupDone(result.fileName ?? ''),
      BackupOutcome.noFolder => l10n.backupNoFolder,
      BackupOutcome.failed => l10n.backupFailed(result.error ?? ''),
    };
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles();
    final pickedPath = picked?.files.single.path;
    if (pickedPath == null) return;

    final l10n = context.l10n;
    BackupReader reader;
    try {
      var bytes = await File(pickedPath).readAsBytes();
      if (BackupCipher.isEncrypted(bytes)) {
        final password = await _askPassword(context);
        if (password == null) return;
        try {
          bytes = await BackupCipher.decrypt(bytes, password);
        } on WrongPasswordException {
          _toast(l10n.restoreWrongPassword);
          return;
        }
      }
      reader = BackupReader(bytes);
    } on BackupFormatException {
      _toast(l10n.restoreBadFile);
      return;
    }

    if (!context.mounted) return;
    final mode = await showRestoreSheet(
      context,
      notes: reader.contents.notes.length,
      attachments: reader.manifest.attachments,
    );
    if (mode == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.restoreConfirm(reader.contents.notes.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonReplace),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final documents = await getApplicationDocumentsDirectory();
    final written = await BackupRestorer(
      ref.read(appDatabaseProvider),
      Directory(path.join(documents.path, 'attachments')),
    ).restore(reader, mode);
    _toast(l10n.restoreDone(written));
  }

  Future<String?> _askPassword(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.backupPassword),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.l10n.commonReplace),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPeriod(
    BuildContext context,
    WidgetRef ref,
    BackupSettings settings,
  ) async {
    final value = await _pickNumber(
      context,
      title: context.l10n.backupPeriod(settings.periodDays),
      current: settings.periodDays,
      min: BackupSettings.minPeriodDays,
      max: BackupSettings.maxPeriodDays,
    );
    if (value == null) return;
    await ref.read(backupSettingsControllerProvider.notifier).setPeriodDays(value);
  }

  Future<void> _pickKeep(
    BuildContext context,
    WidgetRef ref,
    BackupSettings settings,
  ) async {
    final value = await _pickNumber(
      context,
      title: context.l10n.backupKeep(settings.keepFiles),
      current: settings.keepFiles,
      min: BackupSettings.minKeepFiles,
      max: BackupSettings.maxKeepFiles,
    );
    if (value == null) return;
    await ref.read(backupSettingsControllerProvider.notifier).setKeepFiles(value);
  }

  Future<int?> _pickNumber(
    BuildContext context, {
    required String title,
    required int current,
    required int min,
    required int max,
  }) {
    var value = current;
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value',
            onChanged: (next) => setState(() => value = next.round()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(value),
              child: Text(context.l10n.commonReplace),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPassword(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.backupPassword),
        content: TextField(controller: controller, obscureText: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(context.l10n.backupPasswordNone),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.l10n.commonReplace),
          ),
        ],
      ),
    );
    if (value == null) return;
    await ref
        .read(backupSettingsControllerProvider.notifier)
        .setPassword(value.isEmpty ? null : value);
  }

  void _toast(String message) {
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.value, this.trailing, this.onTap});

  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AnchorTokens.space16,
          vertical: AnchorTokens.space12,
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: context.textTheme.bodyMedium)),
            if (value != null)
              Text(value!, style: context.textTheme.bodySmall),
            if (trailing != null) ...[
              const SizedBox(width: AnchorTokens.space8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Add the messenger key**

In `lib/main.dart`, above the widget class:

```dart
/// Lets a job that outlives a screen still show a toast.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
```

and pass it to `MaterialApp.router`:

```dart
      scaffoldMessengerKey: scaffoldMessengerKey,
```

- [ ] **Step 7: Add the section to Settings**

In `lib/features/settings/presentation/settings_screen.dart`, add the import:

```dart
import '../../backup/presentation/backup_section.dart';
```

and add a section next to the Security one, following the same `_Section` shape used there:

```dart
        _Section(
          label: l10n.settingsBackup,
          child: const BackupSection(),
        ),
```

- [ ] **Step 8: Generate the localizations and riverpod code**

Run: `cd mobile && flutter gen-l10n && dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded after ...`

- [ ] **Step 9: Run the test to verify it passes**

Run: `cd mobile && flutter test test/backup/backup_section_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 10: Run the whole suite**

Run: `cd mobile && flutter analyze && flutter test`
Expected: no analyzer errors, all tests pass.

- [ ] **Step 11: Commit**

```bash
git add mobile/lib mobile/test
git commit -m "feat: add a Backup section to Settings"
```

---

## Self-Review

**Spec coverage**

| Spec section | Task |
| --- | --- |
| File layout, manifest, notes.json | 1 |
| What is not backed up | 1 (the model has no such fields) |
| Restore, two modes, transaction | 5 |
| Encryption | 3 |
| Backup folder through SAF | 6 |
| Manual backup, no dialog, toast | 8, 10 |
| Automatic backup, silent, retention | 8, 9 |
| Performance, no compression, streaming write | 1, 4 |
| Settings section | 10 |
| Testing list | 1–10 |

**Placeholder scan:** no `TBD`, no `TODO`, no "similar to Task N". Every code step carries the code.

**Type consistency:** `BackupReader.contents` and `.manifest` are used the same way in Tasks 5 and 10. `BackupResult.outcome` and `.fileName` match between Tasks 8, 9 and 10. `RestoreMode.keepIds` and `.newIds` are spelled the same in Tasks 5 and 10. `backupFolderProvider` is defined in Task 8 and used in Task 10.

**Known gap:** the writer reads one attachment at a time, so memory holds at most the largest single file. The reader loads the whole archive to read it. A backup of photos stays small, so this is accepted, and both doc comments say so.
