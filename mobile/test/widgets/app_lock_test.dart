import 'package:anchor/app/app_bootstrap.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/settings/presentation/app_lock_controller.dart';
import 'package:anchor/features/settings/presentation/app_lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

class _FakeAuthenticator implements DeviceAuthenticator {
  _FakeAuthenticator({this.succeeds = true, this.failure});

  final bool succeeds;

  /// Thrown instead of returning, to stand in for a device that cannot prompt.
  final Object? failure;

  int calls = 0;

  @override
  Future<bool> authenticate() async {
    calls++;
    if (failure != null) throw failure!;
    return succeeds;
  }
}

AppBootstrap _bootstrap({required bool isLocked}) =>
    AppBootstrap(appLockEnabled: isLocked, userId: 'user-1');

ProviderContainer _container({
  required bool isLocked,
  required DeviceAuthenticator authenticator,
}) {
  final container = ProviderContainer(
    overrides: [
      appBootstrapProvider.overrideWithValue(_bootstrap(isLocked: isLocked)),
      deviceAuthenticatorProvider.overrideWithValue(authenticator),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<_FakeAuthenticator> _pump(
  WidgetTester tester, {
  required bool isLocked,
  _FakeAuthenticator? authenticator,
}) async {
  final auth = authenticator ?? _FakeAuthenticator();
  final container = _container(isLocked: isLocked, authenticator: auth);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const AppLockGate(
          child: Scaffold(body: Text('a note about the harbour')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  testWidgets('shows the notes when the lock is off', (tester) async {
    final auth = await _pump(tester, isLocked: false);

    expect(find.text('a note about the harbour'), findsOneWidget);
    expect(find.byType(AppLockScreen), findsNothing);
    expect(auth.calls, 0);
  });

  testWidgets('covers the notes and asks the device on a locked start', (
    tester,
  ) async {
    final auth = await _pump(tester, isLocked: true);

    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(find.text('Anchor is locked'), findsOneWidget);
    expect(auth.calls, 1);
  });

  testWidgets('uncovers the notes once the device lets the person in', (
    tester,
  ) async {
    await _pump(tester, isLocked: true);

    expect(find.byType(AppLockScreen), findsNothing);
    expect(find.text('a note about the harbour'), findsOneWidget);
  });

  testWidgets('keeps the cover and says so when the person cancels', (
    tester,
  ) async {
    await _pump(
      tester,
      isLocked: true,
      authenticator: _FakeAuthenticator(succeeds: false),
    );

    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(find.text('The device did not unlock. Try again.'), findsOneWidget);
  });

  testWidgets('keeps the cover when the device has no screen lock', (
    tester,
  ) async {
    await _pump(
      tester,
      isLocked: true,
      authenticator: _FakeAuthenticator(
        failure: LocalAuthException(
          code: LocalAuthExceptionCode.noCredentialsSet,
        ),
      ),
    );

    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(find.text('Set a screen lock on this device first.'), findsOneWidget);
  });

  testWidgets('covers the notes again when the app goes to the background', (
    tester,
  ) async {
    await _pump(tester, isLocked: true);
    expect(find.byType(AppLockScreen), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(find.byType(AppLockScreen), findsOneWidget);
  });

  test('turning the lock off stores the choice and takes the cover away', () async {
    final container = _container(
      isLocked: true,
      authenticator: _FakeAuthenticator(),
    );
    expect(container.read(appLockControllerProvider), isTrue);

    final problem = await container
        .read(appLockControllerProvider.notifier)
        .setEnabled(false);

    expect(problem, isNull);
    expect(container.read(appLockEnabledProvider), isFalse);
    expect(container.read(appLockControllerProvider), isFalse);
  });

  test('a lock that is off does not cover the notes', () async {
    final container = _container(
      isLocked: false,
      authenticator: _FakeAuthenticator(),
    );

    container.read(appLockControllerProvider.notifier).lock();

    expect(container.read(appLockControllerProvider), isFalse);
  });
}
