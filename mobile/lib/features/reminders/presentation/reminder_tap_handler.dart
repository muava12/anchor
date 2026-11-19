import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/router/pending_launch_route.dart';
import '../data/notification_gateway.dart';
import '../data/reminder_actions.dart';
import 'notification_launch.dart';

part 'reminder_tap_handler.g.dart';

/// Cold-start taps go through `initializeApp`.
@Riverpod(keepAlive: true)
class ReminderTapHandler extends _$ReminderTapHandler {
  @override
  void build() {
    final pending = PendingLaunchRoute(ref);
    final gateway = ref.watch(notificationGatewayProvider);
    final taps = notificationTaps.stream.listen((noteId) {
      final route = notificationRouteForPayload(noteId);
      if (route != null) pending.open(route);
    });
    final actions = reminderActionPresses.stream.listen(
      (action) => unawaited(handleReminderAction(action, gateway: gateway)),
    );
    // A press that landed before this provider existed is not lost.
    for (final action in takePendingReminderActions()) {
      unawaited(handleReminderAction(action, gateway: gateway));
    }
    ref.onDispose(() {
      taps.cancel();
      actions.cancel();
    });
  }
}