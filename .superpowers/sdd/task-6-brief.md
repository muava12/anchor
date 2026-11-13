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

