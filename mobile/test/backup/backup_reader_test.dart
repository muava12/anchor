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
