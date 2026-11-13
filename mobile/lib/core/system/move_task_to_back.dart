import 'dart:io';

import 'package:flutter/services.dart';

/// Sends the app to the background instead of finishing it.
///
/// Android's back arrow at the root of a folder leaves the app open in the
/// background, so the note under the finger is still there on return.
const _channel = MethodChannel('com.zhfahim.anchor/system');

Future<void> moveTaskToBack() async {
  if (!Platform.isAndroid) {
    await SystemNavigator.pop();
    return;
  }
  try {
    await _channel.invokeMethod<bool>('moveTaskToBack');
  } on PlatformException {
    await SystemNavigator.pop();
  } on MissingPluginException {
    await SystemNavigator.pop();
  }
}
