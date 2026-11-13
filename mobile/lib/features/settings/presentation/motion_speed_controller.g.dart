// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'motion_speed_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MotionSpeedController)
final motionSpeedControllerProvider = MotionSpeedControllerProvider._();

final class MotionSpeedControllerProvider
    extends $NotifierProvider<MotionSpeedController, MotionSpeed> {
  MotionSpeedControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'motionSpeedControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$motionSpeedControllerHash();

  @$internal
  @override
  MotionSpeedController create() => MotionSpeedController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MotionSpeed value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MotionSpeed>(value),
    );
  }
}

String _$motionSpeedControllerHash() =>
    r'6f1c2a9d4b8e7f30a5c6d1e2b3a4c5d6e7f80912';

abstract class _$MotionSpeedController extends $Notifier<MotionSpeed> {
  MotionSpeed build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MotionSpeed, MotionSpeed>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MotionSpeed, MotionSpeed>,
              MotionSpeed,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
