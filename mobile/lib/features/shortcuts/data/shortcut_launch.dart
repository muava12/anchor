import 'dart:io';

import 'package:flutter/services.dart';

import '../../../app/router/app_routes.dart';

const _channel = MethodChannel('moek.anchor.notex/shortcuts');

/// Drains the shortcut type the native trampoline stashed, then clears it.
///
/// Returns null on a plain launch, a non-Android platform, or when the channel
/// is not ready (e.g. before the engine has attached).
Future<String?> drainNativeShortcut() async {
  if (!Platform.isAndroid) return null;
  try {
    return await _channel.invokeMethod<String>('drainShortcut');
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

/// The route a shortcut type opens.
///
/// Reminders attach to a note, so `new_reminder` opens the note editor where a
/// reminder is set. Unknown or empty types return null.
String? shortcutRouteFor(String? shortcutType) {
  switch (shortcutType) {
    case 'new_note':
    case 'new_reminder':
      return AppRoutes.newNote;
    case 'new_journal':
      return AppRoutes.journalNew;
    default:
      return null;
  }
}