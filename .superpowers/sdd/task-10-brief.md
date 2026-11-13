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

**Known gap:** the spec says attachments are never read whole into memory. The writer honours that; the reader loads the archive to read it. A backup of photos stays small, so this is accepted, and the reader's doc comment says so.
