import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/anchor_dialog.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/l10n.dart';
import '../data/notification_gateway.dart';
import '../data/reminder_permissions.dart';

enum ReminderPermissionTrigger { userSet, synced }

Future<void> ensureReminderPermissions(
  BuildContext context,
  WidgetRef ref, {
  required ReminderPermissionTrigger trigger,
}) async {
  final controller = ref.read(reminderPermissionsControllerProvider.notifier);
  controller.wasPromptedThisRun = true;
  var permissions = await controller.refresh();

  if (!permissions.canNotify) {
    final isSynced = trigger == ReminderPermissionTrigger.synced;
    if (await controller.hasAskedNotifications()) {
      if (!isSynced && context.mounted) _showTurnOnNotifications(context);
      return;
    }
    if (isSynced) {
      if (!context.mounted) return;
      final shouldContinue = await showAnchorDialog(
        context,
        icon: LucideIcons.bellRing,
        title: context.l10n.reminderNotifyTitle,
        message: context.l10n.reminderNotifyMessage,
        cancelLabel: context.l10n.commonNotNow,
        confirmLabel: context.l10n.commonContinue,
      );
      if (!shouldContinue) return;
    }

    await controller.markNotificationsAsked();
    if (!await controller.requestNotifications()) {
      if (context.mounted) _showTurnOnNotifications(context);
      return;
    }
    permissions = await controller.refresh();
  }

  if (permissions.needsExactAlarmPermission &&
      !permissions.canBeExact &&
      !await controller.hasOfferedExact()) {
    // Offered once, whatever the answer.
    await controller.markExactOffered();
    if (!context.mounted) return;
    final open = await showAnchorDialog(
      context,
      icon: LucideIcons.alarmClock,
      title: context.l10n.reminderExactTitle,
      message: context.l10n.reminderExactMessage,
      cancelLabel: context.l10n.commonNotNow,
      confirmLabel: context.l10n.commonOpenSettings,
    );
    if (open) await controller.openExactSettings();
  }

  if (!context.mounted) return;
  await _offerOverlay(context, ref);
  if (!context.mounted) return;
  await _offerFullScreen(context, ref);
}

/// Android 10+: the escalation sheet needs "display over other apps".
Future<void> _offerOverlay(BuildContext context, WidgetRef ref) async {
  final gateway = ref.read(notificationGatewayProvider);
  if (await gateway.androidSdkInt() < 29) return;
  if (await gateway.canDrawOverlays()) return;
  final controller = ref.read(reminderPermissionsControllerProvider.notifier);
  if (await controller.hasOfferedOverlay()) return;
  // Offered once, whatever the answer.
  await controller.markOverlayOffered();
  if (!context.mounted) return;
  final open = await showAnchorDialog(
    context,
    icon: LucideIcons.copy,
    title: context.l10n.reminderOverlayTitle,
    message: context.l10n.reminderOverlayMessage,
    cancelLabel: context.l10n.commonNotNow,
    confirmLabel: context.l10n.commonOpenSettings,
  );
  if (open) await controller.openOverlaySettings();
}

/// Android 14+: without this grant the heads-up banner auto-dismisses
/// after a few seconds instead of staying until the user acts.
Future<void> _offerFullScreen(BuildContext context, WidgetRef ref) async {
  final gateway = ref.read(notificationGatewayProvider);
  if (await gateway.androidSdkInt() < 34) return;
  if (await gateway.canUseFullScreenIntent()) return;
  final controller = ref.read(reminderPermissionsControllerProvider.notifier);
  if (await controller.hasOfferedFullScreen()) return;
  // Offered once, whatever the answer.
  await controller.markFullScreenOffered();
  if (!context.mounted) return;
  final open = await showAnchorDialog(
    context,
    icon: LucideIcons.bellRing,
    title: context.l10n.reminderFullScreenTitle,
    message: context.l10n.reminderFullScreenMessage,
    cancelLabel: context.l10n.commonNotNow,
    confirmLabel: context.l10n.commonOpenSettings,
  );
  if (open) await gateway.requestFullScreenIntentPermission();
}

void _showTurnOnNotifications(BuildContext context) => AppSnackbar.show(
  context,
  context.l10n.reminderNotificationsOff,
  kind: SnackbarKind.info,
);
