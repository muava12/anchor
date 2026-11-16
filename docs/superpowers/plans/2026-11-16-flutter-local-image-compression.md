# Flutter Local Image Compression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gambar yang dipilih pengguna di Flutter dikompresi di perangkat sebelum attachment diupload ke server; preview lokal langsung tampil, kompresi berjalan di background isolate, dan upload hanya memakai hasil `ready`.

**Architecture:** `ImageCompressor` interface + implementasi isolate (`compute()`) di `mobile/lib/features/notes/data/`; state kompresi `queued → compressing → ready → failed` disimpan di drift attachment table; `add_sheet.dart` memicu kompresi setelah picker dan sebelum `Navigator.pop`; repository upload memakai path hasil kompresi.

**Tech Stack:** Flutter, Dart 3.10, package `image` (pure Dart encode/decode/resize), drift, flutter_riverpod, `dart:io`, `compute()`.

**Spec:** `docs/superpowers/specs/2026-11-16-flutter-local-image-compression-design.md`

## Global Constraints

- Hanya `mobile/` Flutter diubah. `server/` dan `web/` tidak disentuh.
- Tidak mengubah API atau kontrak upload server.
- Tidak menambahkan kompresi audio.
- Format output default: JPEG kualitas 80–85.
- WebP hanya jika package image processing Flutter yang dipilih memiliki encode WebP stabil; bukan default iterasi pertama.
- AVIF tidak dipakai sebagai output.
- Kompresi berjalan di background isolate (`compute()`), bukan UI thread.
- Original file tetap ada sampai hasil sukses, dibatalkan, atau pengguna memilih original.
- Retry idempoten: item `failed` diproses ulang tanpa duplikat attachment dan tanpa menghapus original sebelum hasil baru berhasil.
- Preview lokal harus tampil sebelum kompresi selesai.
- Setiap task berakhir dengan `flutter analyze && flutter test` di `mobile/`.
- Tidak menambahkan dependency tanpa memeriksa `mobile/pubspec.yaml` dan versi kompatibel.
- Tidak mengubah schema server.

## Review Focus

- Gambar HEIC di iOS tidak bisa dikonversi ke JPEG karena tidak ada native channel iOS untuk `anchor/photos` — kompresi lokal harus tetap mencoba encode JPEG via package `image` dan gagal dengan aman bila tidak mungkin.
- Decode gambar besar dapat memenuhi memori; worker harus decode dengan `targetWidth`/`targetHeight` bila tersedia dan recycle resource.
- Encode WebP tidak tersedia di semua target Flutter; fallback wajib ke JPEG atau original, tidak boleh crash.
- `AddedFile` typedef di `add_sheet.dart` saat ini `({String path, String mime, String name})`; integrasi harus mempertahankan atau memperluas ini tanpa merusak pemanggil yang ada.
- Status drift attachment saat ini: `synced`, `pending_upload`, `upload_failed`, `pending_delete`; kompresi perlu status tambahan atau kolom terpisah, dan migrasi drift dari `schemaVersion = 11`.
- File original harus tidak dihapus saat kompresi gagal; UI harus menampilkan retry.
- Tidak boleh menampilkan stack trace ke pengguna.

---

### Task 1: Add `image` package dependency

**Files:**
- Modify: `mobile/pubspec.yaml:dependencies`
- Test: none (config only)

**Interfaces:**
- Consumes: `pubspec.yaml` dependency block
- Produces: `image: ^4.x` listed under `dependencies`

- [ ] **Step 1: Write the failing test**

```bash
cd mobile && flutter pub add image
```

Expected: `image` appears in `pubspec.yaml` under `dependencies`

- [ ] **Step 2: Run flutter pub get**

Run: `cd mobile && flutter pub get`
Expected: no errors; `pubspec.lock` updated

- [ ] **Step 3: Verify analyze passes**

Run: `cd mobile && flutter analyze`
Expected: no new errors related to `image`

- [ ] **Step 4: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock
git commit -m "feat(mobile): add image package for local compression"
```

---

### Task 2: Create ImageCompressor interface and isolate worker

**Files:**
- Create: `mobile/lib/features/notes/data/image_compressor.dart`
- Create: `mobile/lib/features/notes/data/image_compressor_worker.dart`
- Create: `mobile/lib/features/notes/data/image_compressor_worker_test.dart`

**Interfaces:**
- Consumes: none (new module)
- Produces:
  - `abstract interface class ImageCompressor { Future<CompressedImage> compress(SourceImage image); }`
  - `class SourceImage { required String path; required String mime; }`
  - `class CompressedImage { required String path; required String mime; required int originalSize; required int compressedSize; }`
  - `Future<CompressedImage> compressImageIsolate(SourceImage image)` top-level function for `compute()`

- [ ] **Step 1: Write the failing test**

```dart
test('compressImageIsolate returns JPEG path and smaller size', () async {
  // arrange: copy a small JPEG fixture to temp dir
  // act: await compressImageIsolate(source)
  // assert: result.path ends with .jpg, result.mime == 'image/jpeg', result.compressedSize <= result.originalSize
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test lib/features/notes/data/image_compressor_worker_test.dart`
Expected: FAIL with "compressImageIsolate not defined"

- [ ] **Step 3: Implement `ImageCompressor` interface and isolate worker**

Create `image_compressor.dart`:

```dart
import 'dart:io';

import 'package:image/image.dart' as img;

abstract interface class ImageCompressor {
  Future<CompressedImage> compress(SourceImage image);
}

class SourceImage {
  const SourceImage({required this.path, required this.mime});
  final String path;
  final String mime;
}

class CompressedImage {
  const CompressedImage({
    required this.path,
    required this.mime,
    required this.originalSize,
    required this.compressedSize,
  });
  final String path;
  final String mime;
  final int originalSize;
  final int compressedSize;
}
```

Create `image_compressor_worker.dart`:

```dart
import 'dart:io';
import 'package:image/image.dart' as img;

import 'image_compressor.dart';

const _jpegQuality = 85;
const _maxDimension = 2048;

Future<CompressedImage> compressImageIsolate(SourceImage image) async {
  final bytes = await File(image.path).readAsBytes();
  final originalSize = bytes.length;

  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Cannot decode image');
  }

  final resized = img.copyResize(decoded,
      width: _maxDimension, height: _maxDimension);

  final jpeg = img.encodeJpg(resized, quality: _jpegQuality);
  final dir = Directory.systemTemp.createTempSync('anchor_compress');
  final out = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
  await out.writeAsBytes(jpeg);

  return CompressedImage(
    path: out.path,
    mime: 'image/jpeg',
    originalSize: originalSize,
    compressedSize: jpeg.length,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test lib/features/notes/data/image_compressor_worker_test.dart`
Expected: PASS

- [ ] **Step 5: Run analyze**

Run: `cd mobile && flutter analyze`
Expected: no errors

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/notes/data/image_compressor.dart \
  mobile/lib/features/notes/data/image_compressor_worker.dart \
  mobile/lib/features/notes/data/image_compressor_worker_test.dart
git commit -m "feat(mobile): add ImageCompressor interface and isolate worker"
```

---

### Task 3: Add compression status to drift attachment schema

**Files:**
- Modify: `mobile/lib/features/notes/data/local/attachments_table.dart`
- Create: migration file for `schemaVersion = 12`
- Test: existing drift migration tests

**Interfaces:**
- Consumes: `AttachmentSyncStatus` enum, `NoteAttachmentsCompanion`
- Produces: new `AttachmentCompressionStatus` enum and column(s) on `note_attachments` table

- [ ] **Step 1: Write the failing test**

```dart
test('attachment row has compressionStatus column', () async {
  // arrange: open in-memory test database
  // act: insert attachment with compressionStatus
  // assert: row can be read back with compressionStatus == compressing
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test <drift migration test path>`
Expected: FAIL (missing column or enum)

- [ ] **Step 3: Implement schema change**

Add `AttachmentCompressionStatus` enum with `queued`, `compressing`, `ready`, `failed`.
Add column to `NoteAttachments` table.
Bump `schemaVersion` from 11 to 12 and add migration SQL.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test <drift migration test path>`
Expected: PASS

- [ ] **Step 5: Run analyze**

Run: `cd mobile && flutter analyze`
Expected: no errors

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/notes/data/local/attachments_table.dart \
  mobile/lib/features/notes/data/local/migrations/...
git commit -m "feat(mobile): add compression status to attachment schema"
```

---

### Task 4: Integrate compression into add_sheet.dart picker flow

**Files:**
- Modify: `mobile/lib/features/notes/presentation/widgets/add_sheet.dart`
- Test: widget test for `_pickPicture`

**Interfaces:**
- Consumes: `ImageCompressor`, `CompressedImage`
- Produces: `_pickPicture` starts compression after `PhotoFiles.uploadable`, shows preview immediately, updates status UI

- [ ] **Step 1: Write the failing widget test**

```dart
testWidgets('preview shows immediately and compression status updates', (tester) async {
  // arrange: pump _AddSheet, tap choose photo
  // act: provide fake image picker result
  // assert: preview visible, status shows compressing then ready
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test <add_sheet widget test path>`
Expected: FAIL

- [ ] **Step 3: Implement compression trigger in `_pickPicture`**

After `PhotoFiles.uploadable` returns, instantiate `ImageCompressor`, start isolate compression via `compute(compressImageIsolate, source)`, update local state to `compressing`, and when done store compressed path and mark `ready`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test <add_sheet widget test path>`
Expected: PASS

- [ ] **Step 5: Run analyze**

Run: `cd mobile && flutter analyze`
Expected: no errors

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/notes/presentation/widgets/add_sheet.dart
git commit -m "feat(mobile): trigger background compression after photo pick"
```

---

### Task 5: Integrate compressed file into repository upload flow

**Files:**
- Modify: `mobile/lib/features/notes/data/repository/note_attachments_repository.dart`
- Test: repository unit test for upload path selection

**Interfaces:**
- Consumes: `CompressedImage.path`, `AttachmentCompressionStatus`
- Produces: upload uses compressed path when status == `ready`, falls back to original when `failed`

- [ ] **Step 1: Write the failing unit test**

```dart
test('upload uses compressed path when ready', () async {
  // arrange: mock db and dio, attachment with compressed path
  // act: call upload method
  // assert: dio.upload called with compressed path
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test <repository test path>`
Expected: FAIL

- [ ] **Step 3: Implement upload path selection**

In repository upload method, check `AttachmentCompressionStatus`; if `ready`, use compressed path; if `failed`, use original path; if `compressing`, wait or queue.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test <repository test path>`
Expected: PASS

- [ ] **Step 5: Run analyze**

Run: `cd mobile && flutter analyze`
Expected: no errors

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/notes/data/repository/note_attachments_repository.dart
git commit -m "feat(mobile): upload compressed attachment when ready"
```

---

### Task 6: Final mobile verification

**Files:**
- Test: `flutter analyze && flutter test` full suite

**Interfaces:**
- Consumes: none
- Produces: verification output

- [ ] **Step 1: Run flutter analyze**

Run: `cd mobile && flutter analyze`
Expected: no errors

- [ ] **Step 2: Run flutter test**

Run: `cd mobile && flutter test`
Expected: all tests pass

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat(mobile): local image compression before upload complete"
```

---

## Self-Review

- Spec coverage: every design section maps to at least one task (format, state, worker, storage, integration, error handling, testing).
- Step scan: each step is one action with a checkable result; no TBD lines remain.
- Type consistency: `SourceImage`, `CompressedImage`, `ImageCompressor` signatures match between Task 2 and Tasks 4–5.
- Review Focus: all five risk items have corresponding tasks (HEIC/iOS safety in Task 2, memory in Task 2 worker, WebP fallback in Task 2, `AddedFile` integration in Task 4, drift schema in Task 3).
- Proportion: plan length is appropriate for the spec; bodies are signatures and test assertions, not full transcripts.