import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../l10n/l10n.dart';
import '../presentation/notification_launch.dart';
import 'reminder_actions.dart';

part 'notification_gateway.g.dart';

/// How loud a scheduled notification may be on Android.
enum NotificationTier {
  /// Pings at `Importance.max` with `Priority.max`.
  important,

  /// Stays quiet at `Importance.min`, with no sound.
  silent,
}

@Riverpod(keepAlive: true)
NotificationGateway notificationGateway(Ref ref) =>
    LocalNotificationGateway(notificationsPlugin);

class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.repeat,
    required this.payload,
    this.tier = NotificationTier.important,
  });

  final int id;
  final String title;
  final String body;

  /// Local wall-clock time, resolved against the device's zone at schedule time.
  final DateTime at;
  final DateTimeComponents? repeat;
  final String payload;

  /// Which notification channel this notification uses.
  final NotificationTier tier;
}

abstract class NotificationGateway {
  Future<void> initialize();
  Future<List<int>> pendingIds();
  Future<void> schedule(ScheduledNotification notification);
  Future<void> cancel(int id);
  Future<void> cancelAll();
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  bool get requiresExactAlarmPermission;

  /// Android 14+ keeps exact alarms behind a separate grant.
  Future<bool> canScheduleExact();
  Future<void> requestExactPermission();
}

class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// Channel for reminders that must get attention.
  static const importantChannelId = 'reminders';

  /// Channel for quiet notifications, e.g. pinned notes.
  static const silentChannelId = 'pinned_notes';

  /// The Android notification details for a [tier].
  ///
  /// When [bigText] is given, the card opens expanded (big text style) and
  /// shows the full body; a reminder is the note's whole content, one card
  /// per reminder, never grouped. [ongoing] keeps a reminder in the shade
  /// until it is handled; quiet notifications (silent tier) stay dismissible.
  /// [actions] are the buttons under the card, reminders only.
  static AndroidNotificationDetails detailsForTier(
    NotificationTier tier,
    AppLocalizations l10n, {
    String? bigText,
    List<AndroidNotificationAction>? actions,
  }) {
    final important = tier == NotificationTier.important;
    return AndroidNotificationDetails(
      important ? importantChannelId : silentChannelId,
      important ? l10n.reminderChannelName : l10n.pinnedChannelName,
      channelDescription: important
          ? l10n.reminderChannelDescription
          : l10n.pinnedChannelDescription,
      importance: important ? Importance.max : Importance.min,
      priority: important ? Priority.max : Priority.min,
      playSound: important,
      // Must be a flat vector: Android masks the icon to alpha.
      icon: 'ic_stat_reminder',
      color: AnchorTokens.colorBrandOrange,
      styleInformation: bigText == null
          ? null
          : BigTextStyleInformation(bigText),
      ongoing: important,
      actions: actions,
      // Swiping a reminder away quiets that occurrence only.
      dismissIsolate: important ? NotificationDismissedIsolate.main : null,
    );
  }

  static AndroidNotificationChannel _channelFor(
    NotificationTier tier,
    AppLocalizations l10n,
  ) {
    final details = detailsForTier(tier, l10n);
    return AndroidNotificationChannel(
      details.channelId,
      details.channelName,
      description: details.channelDescription,
      importance: details.importance,
      playSound: tier == NotificationTier.important,
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await initializeTimeZonesOnce();
    final android = _android;
    if (android != null) {
      final l10n = deviceL10n();
      for (final tier in NotificationTier.values) {
        await android.createNotificationChannel(_channelFor(tier, l10n));
      }
    }
    _initialized = true;
  }

  @override
  Future<List<int>> pendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((request) => request.id).toList();
  }

  @override
  Future<void> schedule(ScheduledNotification notification) async {
    final at = tz.TZDateTime.from(notification.at, tz.local);
    final l10n = deviceL10n();
    final mode = await canScheduleExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await _plugin.zonedSchedule(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      scheduledDate: at,
      notificationDetails: NotificationDetails(
        android: detailsForTier(
          notification.tier,
          l10n,
          bigText: notification.body,
          actions: notification.tier == NotificationTier.important
              ? reminderActions(l10n)
              : null,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: mode,
      matchDateTimeComponents: notification.repeat,
      payload: notification.payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<bool> hasPermission() async {
    try {
      final android = await _android?.areNotificationsEnabled();
      final ios = (await _ios?.checkPermissions())?.isEnabled;
      return android ?? ios ?? true;
    } catch (error, stack) {
      AppLogger.instance.error(
        LogTags.notifications,
        'Notification permission check failed',
        error: error,
        stackTrace: stack,
      );
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final android = await _android?.requestNotificationsPermission();
      final ios = await _ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return android ?? ios ?? true;
    } catch (error, stack) {
      AppLogger.instance.error(
        LogTags.notifications,
        'Notification permission request failed',
        error: error,
        stackTrace: stack,
      );
      return false;
    }
  }

  @override
  bool get requiresExactAlarmPermission => Platform.isAndroid;

  @override
  Future<bool> canScheduleExact() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> requestExactPermission() async {
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (error, stack) {
      AppLogger.instance.error(
        LogTags.notifications,
        'Exact alarm request failed',
        error: error,
        stackTrace: stack,
      );
    }
  }
}

bool _timeZonesReady = false;

/// Loads the timezone database once; sets `tz.local` to the device's zone on
/// every call.
Future<void> initializeTimeZonesOnce() async {
  if (!_timeZonesReady) {
    tzdata.initializeTimeZones();
    _timeZonesReady = true;
  }
  await syncLocalTimeZone();
}

Future<void> syncLocalTimeZone() async {
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (error) {
    // An unknown IANA name throws; UTC is the fallback.
    AppLogger.instance.warn(
      LogTags.notifications,
      'Falling back to UTC: $error',
    );
  }
}
