import 'package:anchor/core/motion/motion_speed.dart';
import 'package:anchor/core/motion/springs.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/features/settings/presentation/motion_speed_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => MotionSpeed.current = MotionSpeed.slow);

  test('slow keeps the design durations', () {
    expect(MotionSpeed.slow.scale, 1);
  });

  test('fast runs at three tenths', () {
    expect(MotionSpeed.fast.scale, 0.3);
  });

  test('off has no time at all', () {
    expect(MotionSpeed.off.scale, 0);
  });

  test('the current speed starts at slow', () {
    expect(MotionSpeed.current, MotionSpeed.slow);
  });

  test('a spring keeps its design duration at slow', () {
    MotionSpeed.current = MotionSpeed.slow;
    expect(Spring.smooth.duration, AnchorTokens.motionSpringSmoothDuration);
  });

  test('a spring is three tenths as long at fast', () {
    MotionSpeed.current = MotionSpeed.fast;
    expect(
      Spring.smooth.duration.inMicroseconds,
      (AnchorTokens.motionSpringSmoothDuration.inMicroseconds * 0.3).round(),
    );
  });

  test('a spring has no duration at off', () {
    MotionSpeed.current = MotionSpeed.off;
    expect(Spring.smooth.duration, Duration.zero);
  });

  test('off counts as reduced motion', () {
    MotionSpeed.current = MotionSpeed.off;
    expect(isSystemMotionReduced, isTrue);
  });

  test('an unknown stored name reads as slow', () {
    expect(motionSpeedFromName('nonsense'), MotionSpeed.slow);
    expect(motionSpeedFromName(null), MotionSpeed.slow);
    expect(motionSpeedFromName('fast'), MotionSpeed.fast);
  });
}
