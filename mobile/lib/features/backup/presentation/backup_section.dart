import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/motion/haptics.dart';
import '../../../core/motion/springs.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/switch_row.dart';
import '../../../l10n/l10n.dart';
import '../../../main.dart' show scaffoldMessengerKey;
import '../data/backup_cipher.dart';
import '../data/backup_reader.dart';
import '../data/backup_restorer.dart';
import '../domain/backup_settings.dart';
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
        GroupedListTile(
          icon: LucideIcons.archive,
          label: l10n.backupFolder,
          value: settings.folderDisplayName ?? l10n.backupChooseFolder,
          showChevron: true,
          onTap: () => _pickFolder(context, ref),
        ),
        GroupedListTile(
          icon: LucideIcons.download,
          label: running ? l10n.backupRunning : l10n.backupNow,
          showChevron: !running,
          trailing: running
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: running ? null : () => _backupNow(context, ref),
        ),
        GroupedListTile(
          icon: LucideIcons.archiveRestore,
          label: l10n.backupRestore,
          showChevron: !running,
          onTap: running ? null : () => _restore(context, ref),
        ),
        SwitchRow(
          icon: LucideIcons.history,
          label: l10n.backupAutomatic,
          value: settings.automatic,
          onChanged: (value) => ref
              .read(backupSettingsControllerProvider.notifier)
              .setAutomatic(value),
        ),
        GroupedListTile(
          icon: LucideIcons.calendarClock,
          label: l10n.backupPeriod(settings.periodDays),
          showChevron: true,
          onTap: () => _pickPeriod(context, ref, settings),
        ),
        GroupedListTile(
          icon: LucideIcons.copy,
          label: l10n.backupKeep(settings.keepFiles),
          showChevron: true,
          onTap: () => _pickKeep(context, ref, settings),
        ),
        GroupedListTile(
          icon: LucideIcons.keyRound,
          label: l10n.backupPassword,
          value: settings.password == null ? l10n.backupPasswordNone : '••••••',
          showChevron: true,
          onTap: () => _pickPassword(context, ref),
        ),
      ],
    );
  }

  Future<void> _pickFolder(BuildContext context, WidgetRef ref) async {
    final choice = await ref.read(backupFolderProvider).pick();
    if (choice == null) return;
    await ref
        .read(backupSettingsControllerProvider.notifier)
        .setFolder(choice.uri, name: choice.name);
  }

  Future<void> _backupNow(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final result = await ref
        .read(backupControllerProvider.notifier)
        .run(automatic: false);
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
    final picked = await FilePicker.pickFile();
    final pickedPath = picked?.path;
    if (pickedPath == null || !context.mounted) return;

    final l10n = context.l10n;
    BackupReader reader;
    try {
      List<int> bytes = await File(pickedPath).readAsBytes();
      if (BackupCipher.isEncrypted(bytes)) {
        if (!context.mounted) return;
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
            child: Text(context.l10n.commonSave),
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
      description: context.l10n.backupPeriodDesc,
      leftLabel: context.l10n.backupEvery,
      unit: context.l10n.backupDaysUnit,
      current: settings.periodDays,
      min: BackupSettings.minPeriodDays,
      max: BackupSettings.maxPeriodDays,
      chips: [
        (context.l10n.backupDaily, 1),
        (context.l10n.backupWeekly, 7),
        (context.l10n.backupMonthly, 30),
      ],
    );
    if (value == null) return;
    await ref
        .read(backupSettingsControllerProvider.notifier)
        .setPeriodDays(value);
  }

  Future<void> _pickKeep(
    BuildContext context,
    WidgetRef ref,
    BackupSettings settings,
  ) async {
    final value = await _pickNumber(
      context,
      title: context.l10n.backupKeep(settings.keepFiles),
      description: context.l10n.backupKeepDesc,
      leftLabel: context.l10n.backupKeepWord,
      unit: context.l10n.backupFilesUnit,
      current: settings.keepFiles,
      min: BackupSettings.minKeepFiles,
      max: BackupSettings.maxKeepFiles,
    );
    if (value == null) return;
    await ref
        .read(backupSettingsControllerProvider.notifier)
        .setKeepFiles(value);
  }

  Future<int?> _pickNumber(
    BuildContext context, {
    required String title,
    required String description,
    required String leftLabel,
    required String unit,
    required int current,
    required int min,
    required int max,
    List<(String label, int value)>? chips,
  }) {
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => _BackupNumberDialog(
        title: title,
        description: description,
        leftLabel: leftLabel,
        unit: unit,
        current: current,
        min: min,
        max: max,
        chips: chips,
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

/// The redesigned number dialog: big accent value + unit, styled slider,
/// min/max ends, and optional quick-pick chips (period dialog only).
class _BackupNumberDialog extends StatefulWidget {
  const _BackupNumberDialog({
    required this.title,
    required this.description,
    required this.leftLabel,
    required this.unit,
    required this.current,
    required this.min,
    required this.max,
    this.chips,
  });

  final String title;
  final String description;
  final String leftLabel;
  final String unit;
  final int current;
  final int min;
  final int max;
  final List<(String label, int value)>? chips;

  @override
  State<_BackupNumberDialog> createState() => _BackupNumberDialogState();
}

class _BackupNumberDialogState extends State<_BackupNumberDialog> {
  late int _value = widget.current;

  void _setValue(int next, {bool haptic = true}) {
    if (next == _value) return;
    if (haptic) Haptics.selection();
    setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: colors.appSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AnchorTokens.radius2xl),
      ),
      title: Text(
        widget.title,
        style: AppTypography.cardTitle.copyWith(color: colors.appText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.description,
            style: AppTypography.secondary.copyWith(color: colors.appMuted),
          ),
          const SizedBox(height: AnchorTokens.space16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.leftLabel,
                style: AppTypography.row.copyWith(color: colors.appText),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$_value',
                      style: AppTypography.largeTitle.tabular.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.accentStrong,
                      ),
                    ),
                    TextSpan(
                      text: ' ${widget.unit}',
                      style: AppTypography.footnote.copyWith(
                        color: colors.appMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AnchorTokens.space12),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: colors.accentStrong,
              inactiveTrackColor: colors.appBorder,
              thumbColor: colors.appText,
              overlayColor: colors.accentStrong.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
            ),
            child: Slider(
              value: _value.toDouble().clamp(
                widget.min.toDouble(),
                widget.max.toDouble(),
              ),
              min: widget.min.toDouble(),
              max: widget.max.toDouble(),
              divisions: widget.max - widget.min,
              onChanged: (next) => _setValue(next.round(), haptic: false),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.min}',
                style: AppTypography.footnote.copyWith(color: colors.appMuted),
              ),
              Text(
                '${widget.max}',
                style: AppTypography.footnote.copyWith(color: colors.appMuted),
              ),
            ],
          ),
          if (widget.chips != null) ...[
            const SizedBox(height: AnchorTokens.space16),
            Wrap(
              spacing: AnchorTokens.space8,
              children: [
                for (final chip in widget.chips!)
                  _QuickChip(
                    label: chip.$1,
                    isOn: _value == chip.$2,
                    onTap: () => _setValue(chip.$2),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_value),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.isOn,
    required this.onTap,
  });

  final String label;
  final bool isOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Pressable(
      style: PressStyle.plain,
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: Spring.snappy.duration,
        curve: Spring.snappy.curve,
        padding: const EdgeInsets.symmetric(
          horizontal: AnchorTokens.space16,
          vertical: AnchorTokens.space8,
        ),
        decoration: BoxDecoration(
          color: isOn ? colors.accentStrong : colors.appPage,
          borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
          border: Border.all(
            color: isOn ? colors.accentStrong : colors.appBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.chip.copyWith(
            color: isOn ? colors.appSurface : colors.appMuted,
            fontWeight: isOn ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
