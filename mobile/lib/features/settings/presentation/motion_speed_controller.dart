import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/app_bootstrap.dart';
import '../../../core/motion/motion_speed.dart';
import '../../../core/storage/preferences_repository.dart';

part 'motion_speed_controller.g.dart';

/// The stored name, or slow when it is missing or unknown.
MotionSpeed motionSpeedFromName(String? name) => MotionSpeed.values.firstWhere(
  (speed) => speed.name == name,
  orElse: () => MotionSpeed.slow,
);

@Riverpod(keepAlive: true)
class MotionSpeedController extends _$MotionSpeedController {
  @override
  MotionSpeed build() => ref.watch(appBootstrapProvider).motionSpeed;

  Future<void> set(MotionSpeed speed) async {
    state = speed;
    MotionSpeed.current = speed;
    await ref
        .read(preferencesRepositoryProvider)
        .setMotionSpeedName(speed.name);
  }
}
