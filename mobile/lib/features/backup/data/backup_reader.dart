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
