# Task 6 report — Pick the backup folder

## Status

DONE_WITH_CONCERNS

## Files created

- `mobile/android/app/src/main/kotlin/com/zhfahim/anchor/backup/BackupFolderPlugin.kt` (new, verbatim from brief)
- `mobile/lib/features/backup/data/backup_folder.dart` (new, verbatim from brief)
- `mobile/test/backup/backup_folder_test.dart` (new, verbatim from brief)

## Files modified

- `mobile/android/app/src/main/kotlin/com/zhfahim/anchor/MainActivity.kt`
  - added `import com.zhfahim.anchor.backup.BackupFolderPlugin` (kept import order alphabetical, before `photos`)
  - added `flutterEngine.plugins.add(BackupFolderPlugin())` as the first `plugins.add` line inside `configureFlutterEngine`, before `PhotoConverterPlugin()` and `ShareFolderPlugin(listens = true)`

No other file touched. Nothing committed.

## Steps I could not run

- Step 2 (`flutter test` → expect FAIL) and Step 6 (`flutter test` → expect PASS): no Flutter/Dart toolchain on this host (`which flutter dart` returns nothing). The controller runs these on the remote host.
- Step 7 (`flutter build apk --debug`): same reason. The Kotlin compile is therefore **unverified**.
- Step 8 (commit): explicitly out of scope for this task; the controller commits.

## Concerns

1. **`androidx.documentfile` is not declared as a dependency.** `BackupFolderPlugin.kt` imports `androidx.documentfile.provider.DocumentFile`, but `mobile/android/app/build.gradle.kts` has only `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")` in `dependencies`. I could not confirm a transitive provider: no Gradle cache, no pub cache, and no Flutter SDK on this host, so I cannot inspect the resolved dependency graph. If nothing pulls it in, Step 7 fails with `Unresolved reference: documentfile`. Fix, if needed, is one line in `mobile/android/app/build.gradle.kts`:
   ```kotlin
   implementation("androidx.documentfile:documentfile:1.0.1")
   ```
   I did not add it because that file is outside the files this task allows me to touch. The controller should decide.

2. **`writeFile` sends `List<int>` over the channel, Kotlin reads `ByteArray`.** The Dart side passes `bytes` as `List<int>`; the standard message codec encodes a `Uint8List` as `byte[]` but a plain `List<int>` as `int[]`/`List<Object>`. `call.argument<ByteArray>("bytes")` then returns `null` and the call fails with `bad_args`. The brief's test only checks the arguments map, so it passes either way. This is a runtime risk for the real caller in a later task: it must pass a `Uint8List` (e.g. `Uint8List.fromList(bytes)`), or the plugin must accept `List<Int>` and convert. I wrote the code exactly as the brief shows and did not change it.

3. **`folderOf` returns `null` when `activity` is `null`**, so `listFiles`/`deleteFile`/`writeFile` report `bad_args` instead of a clearer error after a detach. Matches the brief; noted only.

4. **`onActivityResult` returns `false` for a non-matching request code** and for a missing `pending` result, which is correct for the listener contract, but a `pickFolder` result left pending across a config change is dropped silently (the `pending` field survives, the activity does not). Matches the brief; noted only.

5. **`takePersistableUriPermission` flags** are masked from `data.flags`; if the provider grants only read, the write grant is not persisted and later writes fail. Matches the brief; noted only.
