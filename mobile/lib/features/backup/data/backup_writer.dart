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
    _encoder.addArchiveFile(ArchiveFile(name, bytes.length, bytes));
  }

  Future<void> addFile(File source, String name) async {
    final bytes = await source.readBytes();
    _encoder.addArchiveFile(ArchiveFile(name, bytes.length, bytes));
  }

  Future<void> close() async {
    _encoder.close();
  }
}
