// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(backupFolder)
final backupFolderProvider = BackupFolderProvider._();

final class BackupFolderProvider
    extends $FunctionalProvider<BackupFolder, BackupFolder, BackupFolder>
    with $Provider<BackupFolder> {
  BackupFolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupFolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupFolderHash();

  @$internal
  @override
  $ProviderElement<BackupFolder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BackupFolder create(Ref ref) {
    return backupFolder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackupFolder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackupFolder>(value),
    );
  }
}

String _$backupFolderHash() => r'0fac97e1e5737738a8686566c229a690abc6084a';

/// True while a backup runs. Kept alive so leaving Settings does not stop it.

@ProviderFor(BackupController)
final backupControllerProvider = BackupControllerProvider._();

/// True while a backup runs. Kept alive so leaving Settings does not stop it.
final class BackupControllerProvider
    extends $NotifierProvider<BackupController, bool> {
  /// True while a backup runs. Kept alive so leaving Settings does not stop it.
  BackupControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupControllerHash();

  @$internal
  @override
  BackupController create() => BackupController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$backupControllerHash() => r'e8574ba8168e45aa8aa1078a83dd12fa97dc0a12';

/// True while a backup runs. Kept alive so leaving Settings does not stop it.

abstract class _$BackupController extends $Notifier<bool> {
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
