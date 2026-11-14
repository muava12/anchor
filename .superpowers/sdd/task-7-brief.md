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

