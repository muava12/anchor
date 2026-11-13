// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_lock_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deviceAuthenticator)
final deviceAuthenticatorProvider = DeviceAuthenticatorProvider._();

final class DeviceAuthenticatorProvider
    extends
        $FunctionalProvider<
          DeviceAuthenticator,
          DeviceAuthenticator,
          DeviceAuthenticator
        >
    with $Provider<DeviceAuthenticator> {
  DeviceAuthenticatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceAuthenticatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceAuthenticatorHash();

  @$internal
  @override
  $ProviderElement<DeviceAuthenticator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeviceAuthenticator create(Ref ref) {
    return deviceAuthenticator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceAuthenticator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceAuthenticator>(value),
    );
  }
}

String _$deviceAuthenticatorHash() =>
    r'4b1f0f0b8f0b0f0b8f0b0f0b8f0b0f0b8f0b0f0b';

@ProviderFor(localAuthentication)
final localAuthenticationProvider = LocalAuthenticationProvider._();

final class LocalAuthenticationProvider
    extends
        $FunctionalProvider<
          LocalAuthentication,
          LocalAuthentication,
          LocalAuthentication
        >
    with $Provider<LocalAuthentication> {
  LocalAuthenticationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localAuthenticationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localAuthenticationHash();

  @$internal
  @override
  $ProviderElement<LocalAuthentication> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LocalAuthentication create(Ref ref) {
    return localAuthentication(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalAuthentication value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalAuthentication>(value),
    );
  }
}

String _$localAuthenticationHash() =>
    r'9c2b1a0d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b';

@ProviderFor(AppLockEnabled)
final appLockEnabledProvider = AppLockEnabledProvider._();

final class AppLockEnabledProvider
    extends $NotifierProvider<AppLockEnabled, bool> {
  AppLockEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLockEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLockEnabledHash();

  @$internal
  @override
  AppLockEnabled create() => AppLockEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$appLockEnabledHash() => r'1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b';

abstract class _$AppLockEnabled extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(AppLockController)
final appLockControllerProvider = AppLockControllerProvider._();

final class AppLockControllerProvider
    extends $NotifierProvider<AppLockController, bool> {
  AppLockControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLockControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLockControllerHash();

  @$internal
  @override
  AppLockController create() => AppLockController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$appLockControllerHash() => r'0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c';

abstract class _$AppLockController extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
