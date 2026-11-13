# Task 10 report — Backup section in Settings

Status: DONE_WITH_CONCERNS

## Files created

- `mobile/lib/features/backup/presentation/backup_section.dart` — `BackupSection` (ConsumerWidget), private `_Row`.
- `mobile/lib/features/backup/presentation/restore_sheet.dart` — `showRestoreSheet(context, {notes, attachments})`, `_RestoreSheet`, `_ModeTile`.
- `mobile/test/backup/backup_section_test.dart` — the two widget tests from the brief.

## Files changed

- `mobile/lib/main.dart` — added `final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();` above `AnchorApp`, and `scaffoldMessengerKey: scaffoldMessengerKey` on `MaterialApp.router`.
- `mobile/lib/features/settings/presentation/settings_screen.dart` — added `import '../../backup/presentation/backup_section.dart';` and a `Section(label: context.l10n.settingsBackup, child: const BackupSection())` between `_SecuritySection` and `_AccountSection`.
- `mobile/lib/l10n/app_en.arb` — added 24 new keys (all `backup*`, `restore*`, `settingsBackup`, `commonReplace`) before the closing brace.

## Where I did not follow the brief, and why

1. **`_Section` does not exist.** The real `settings_screen.dart` uses the public `Section` widget from `lib/core/widgets/grouped_list.dart` (`Section({required label, required child, isBoxed})`). I used `Section(label: context.l10n.settingsBackup, child: const BackupSection())`. The brief's `_Section` snippet was illustrative, as stated.
2. **`context.textTheme` does not exist.** `lib/core/theme/context_extensions.dart` has no `textTheme` getter. In `restore_sheet.dart` and in `_Row` I used `Theme.of(context).textTheme` (the pattern already used in `settings_screen.dart` and `app_lock_gate.dart`). The `context_extensions.dart` import became unused and was dropped from both new files.
3. **`AnchorTokens.radius12` does not exist.** The token scale is `radiusXs/Sm/Md/Lg/Xl/2xl/...`. `radius12` was replaced with `AnchorTokens.radiusLg` (12.0), the same value.
4. **`commonCancel` already exists** in `app_en.arb` (line 11, with a description). Adding the brief's copy would have produced a duplicate JSON key and broken `gen-l10n`. I added only `commonReplace`; `commonCancel` is reused as-is.
5. **`appDatabaseProvider` import.** The brief imported `../../notes/data/repository/note_attachments_repository.dart`, which does not export `appDatabaseProvider` and is otherwise unused. I imported `../../../core/database/app_database.dart` instead (where `appDatabaseProvider` is generated). The unused `backup_folder.dart` and `restore_mode.dart` imports from the brief were dropped for the same reason (`backupFolderProvider` lives in `backup_controller.dart`; `RestoreMode` is only used through inference).
6. **Two `use_build_context_synchronously` guards added** (the brief's code would trip the lint under `flutter_lints`, which this repo enables):
   - `_backupNow`: `final l10n = context.l10n;` moved above the `await`.
   - `_restore`: `if (pickedPath == null || !context.mounted) return;` and `if (!context.mounted) return;` before `_askPassword(context)`.
7. **Line wrapping** to match `dart format` at 80 columns in three places (the folder row's ternary, `setPeriodDays`, `setKeepFiles`) and in the test's `home:` argument. No behaviour change.

## Not run (per instructions)

`flutter gen-l10n`, `dart run build_runner build`, `flutter analyze`, `flutter test` were **not** run: this host has no Flutter toolchain. Nothing was committed.

## Concerns

1. **Generated localizations are stale.** `lib/l10n/app_localizations.dart` and `app_localizations_en.dart` are tracked files and do not yet contain the 24 new getters, so the new code does not compile until `flutter gen-l10n` runs. Those two files are outside the file list I was allowed to touch, so I left them alone. `flutter gen-l10n` must run before `flutter analyze` / `flutter test`.
2. **Possible `unused_field` warning.** `_RestoreSheet` stores `notes` and `attachments` but the brief's `build` reads neither. If the analyzer reports them, the fix is to show `l10n.notesCount(notes)` as a subtitle under the sheet title (existing key, no new copy) and to drop the `attachments` field. I kept the brief's code verbatim rather than invent copy.
3. **No dividers between the `_Row`s.** `GroupedList` only draws the line above a child when the previous child is a `GroupedListTile`, `SwitchRow`, `StackedListTile` or `GroupedListRow`. The brief's `_Row` is none of these, so the Backup rows render without separators, unlike every other Settings section. Making `_Row` extend `GroupedListRow` (with `dividerStart: GroupedListTile.inset`) would fix it; I did not, because the brief specifies the widget.
4. **`_Row` uses `InkWell` and `Theme.of(context).textTheme`**, while the rest of Settings uses `GroupedListTile` + `AppTypography`. The Backup section will look slightly different from its neighbours (font, press feedback, no chevron). Not a compile risk.
5. **`commonReplace` is used as the confirm label for non-destructive dialogs** — the period slider, the keep-files slider and the password dialog all show "Replace". That reads wrong for "Every 7 days" or "Password". The brief's code does this; a `commonDone`/`commonSave` label would be better.
6. **`_pickPassword` cannot tell "cancel" from "clear".** The "None" button pops `''`, which clears the password; dismissing the dialog pops `null`, which keeps it. That works, but the dialog has no visible "clear" affordance beyond the "None" button.
7. **`backup_section.dart` imports `main.dart`** for `scaffoldMessengerKey`, creating an import cycle (`main.dart` → router → `settings_screen.dart` → `backup_section.dart` → `main.dart`). Dart allows it and the brief asks for it, but a small `lib/core/ui/messenger.dart` would be cleaner.
8. **Restore is not guarded against a running backup** beyond the row being disabled, and `BackupRestorer` is constructed inline in the widget. Business logic stays in the restorer, so this is acceptable, but the restore path has no progress indicator: a large backup shows a frozen screen until the toast appears.
