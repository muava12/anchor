// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BackupSettingsController)
final backupSettingsControllerProvider = BackupSettingsControllerProvider._();

final class BackupSettingsControllerProvider
    extends $AsyncNotifierProvider<BackupSettingsController, BackupSettings> {
  BackupSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupSettingsControllerHash();

  @$internal
  @override
  BackupSettingsController create() => BackupSettingsController();
}

String _$backupSettingsControllerHash() =>
    r'15b9e98e0f9b6a2d9620f39153ee92fd6e9a28bf';

abstract class _$BackupSettingsController
    extends $AsyncNotifier<BackupSettings> {
  FutureOr<BackupSettings> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<BackupSettings>, BackupSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<BackupSettings>, BackupSettings>,
              AsyncValue<BackupSettings>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
