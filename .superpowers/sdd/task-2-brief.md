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

