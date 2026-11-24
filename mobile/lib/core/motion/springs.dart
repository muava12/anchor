import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../theme/tokens/anchor_tokens.dart';
import 'motion_speed.dart';

enum Spring {
  smooth(
    AnchorTokens.motionSpringSmoothDuration,
    AnchorTokens.motionSpringSmoothBounce,
  ),

  snappy(
    AnchorTokens.motionSpringSnappyDuration,
    AnchorTokens.motionSpringSnappyBounce,
  ),

  pop(AnchorTokens.motionSpringPopDuration, AnchorTokens.motionSpringPopBounce),

  keyboard(
    AnchorTokens.motionSpringKeyboardDuration,
    AnchorTokens.motionSpringKeyboardBounce,
  );

  const Spring(this._duration, this._bounce);

  final Duration _duration;
  final double _bounce;

  /// The design duration, shortened or removed by the motion setting.
  Duration get duration => _duration * MotionSpeed.current.scale;

  /// The design duration, whatever the motion setting says.
  ///
  /// For the few animations that must keep their Normal feel, such as the notes
  /// bottom bar shrinking into a search button. A setting of Off still means no
  /// time at all; use [BuildContext.motionNormal] for that.
  Duration get durationNormal => _duration;

  Curve get curve => _SpringCurve(simulation(0, 1));

  /// The design curve, whatever the motion setting says.
  ///
  /// [curve] is built from the shortened [duration], so at Fast it is stiffer
  /// than at Normal. This one always uses the design duration.
  Curve get curveNormal => _SpringCurve(simulationNormal(0, 1));

  /// Starts at [velocity] (units per second) and lands exactly on [to] once
  /// it is within [precision] of it.
  Simulation simulation(
    double from,
    double to, {
    double velocity = 0,
    double precision = 0.0005,
  }) => _spring(
    duration,
    from,
    to,
    velocity: velocity,
    precision: precision,
  );

  /// [simulation] with the design duration, ignoring the motion setting.
  Simulation simulationNormal(
    double from,
    double to, {
    double velocity = 0,
    double precision = 0.0005,
  }) => _spring(
    durationNormal,
    from,
    to,
    velocity: velocity,
    precision: precision,
  );

  Simulation _spring(
    Duration springDuration,
    double from,
    double to, {
    required double velocity,
    required double precision,
  }) => _SettlingSpring(
    SpringSimulation(
      SpringDescription.withDurationAndBounce(
        duration: springDuration,
        bounce: _bounce,
      ),
      from,
      to,
      velocity,
      tolerance: Tolerance(distance: precision, velocity: precision * 20),
    ),
    to,
  );
}

class _SettlingSpring extends Simulation {
  _SettlingSpring(this._spring, this._to) : super(tolerance: _spring.tolerance);

  final SpringSimulation _spring;
  final double _to;

  @override
  double x(double time) => _spring.isDone(time) ? _to : _spring.x(time);

  @override
  double dx(double time) => _spring.isDone(time) ? 0 : _spring.dx(time);

  @override
  bool isDone(double time) => _spring.isDone(time);
}

class _SpringCurve extends Curve {
  _SpringCurve(this._run);

  final Simulation _run;

  late final double _end = _settleTime();

  double _settleTime() {
    var time = 0.0;
    while (time < 3 && !_run.isDone(time)) {
      time += 1 / 240;
    }
    return time;
  }

  @override
  double transformInternal(double t) => t >= 1 ? 1 : _run.x(t * _end);
}

/// Android's Remove animations comes through [disableAnimations]; iOS's
/// Reduce Motion has its own flag.
bool _reducesMotion(bool disableAnimations) =>
    disableAnimations ||
    WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .reduceMotion;

/// The system's reduced motion setting, or the app's own "off", for code
/// without a [BuildContext].
bool get isSystemMotionReduced =>
    _reducesMotion(SemanticsBinding.instance.disableAnimations) ||
    MotionSpeed.current == MotionSpeed.off;

extension SpringController on AnimationController {
  /// [velocity] is in units per second; with reduced motion it jumps
  /// straight there.
  TickerFuture springTo(
    double target, {
    Spring spring = Spring.smooth,
    double velocity = 0,
  }) {
    if (isSystemMotionReduced) {
      value = target;
      return TickerFuture.complete();
    }
    return animateWith(spring.simulation(value, target, velocity: velocity));
  }

  /// [springTo] in reverse: the controller ends dismissed.
  TickerFuture springBackTo(
    double target, {
    Spring spring = Spring.smooth,
    double velocity = 0,
  }) {
    if (isSystemMotionReduced) {
      value = target;
      return TickerFuture.complete();
    }
    return animateBackWith(
      spring.simulation(value, target, velocity: velocity),
    );
  }
}

extension ReducedMotion on BuildContext {
  bool get isMotionReduced =>
      _reducesMotion(MediaQuery.maybeDisableAnimationsOf(this) ?? false) ||
      MotionSpeed.current == MotionSpeed.off;

  /// [duration], shortened by the motion setting, or no time at all.
  Duration motion(Duration duration) =>
      isMotionReduced ? Duration.zero : duration * MotionSpeed.current.scale;

  /// A spring's design duration and curve, kept at Normal even when the motion
  /// setting is Fast.
  ///
  /// Off still means no time at all, and so does a system that asks for reduced
  /// motion: an override for the fast setting must not defeat accessibility.
  Duration motionNormal(Duration duration) =>
      isMotionReduced ? Duration.zero : duration;
}
