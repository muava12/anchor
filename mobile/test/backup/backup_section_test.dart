import 'package:anchor/core/widgets/grouped_list.dart';
import 'package:anchor/features/backup/domain/backup_settings.dart';
import 'package:anchor/features/backup/presentation/backup_controller.dart';
import 'package:anchor/features/backup/presentation/backup_section.dart';
import 'package:anchor/features/backup/presentation/backup_settings_controller.dart';
import 'package:anchor/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FakeSettings extends BackupSettingsController {
  FakeSettings(this.initial);

  final BackupSettings initial;
  final List<int> periodCalls = [];
  final List<int> keepCalls = [];

  @override
  Future<BackupSettings> build() async => initial;

  @override
  Future<void> setPeriodDays(int days) async => periodCalls.add(days);

  @override
  Future<void> setKeepFiles(int count) async => keepCalls.add(count);
}

class FakeBackup extends BackupController {
  @override
  bool build() => false;
}

void main() {
  FakeSettings? fake;

  Future<void> pump(WidgetTester tester, BackupSettings settings) async {
    final notifier = FakeSettings(settings);
    fake = notifier;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupSettingsControllerProvider.overrideWith(
            () => notifier,
          ),
          backupControllerProvider.overrideWith(FakeBackup.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: BackupSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('with no folder it asks for one', (tester) async {
    await pump(tester, const BackupSettings());
    expect(find.text('Choose a folder'), findsOneWidget);
  });

  testWidgets('the folder row uses the shared tile and a chevron', (tester) async {
    await pump(
      tester,
      const BackupSettings(
        folderUri: 'content://tree/backups',
        folderName: 'Backups',
      ),
    );
    expect(find.byType(GroupedListTile), findsWidgets);
    expect(find.byIcon(LucideIcons.chevronRight), findsWidgets);
  });

  testWidgets('with a folder it offers a backup now', (tester) async {
    await pump(
      tester,
      const BackupSettings(
        folderUri: 'content://tree/backups',
        folderName: 'Backups',
      ),
    );
    expect(find.text('Backups'), findsOneWidget);
    expect(find.text('Back up now'), findsOneWidget);
    expect(find.text('Choose a folder'), findsNothing);
  });

  testWidgets('the period dialog shows description, value, chips and ends',
      (tester) async {
    await pump(tester, const BackupSettings());
    await tester.tap(find.text('Every 7 days'));
    await tester.pumpAndSettle();

    expect(
      find.text('How often Anchor makes an automatic backup'),
      findsOneWidget,
    );
    // Quick-pick chips only on the period dialog.
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    // Range ends.
    expect(find.text('1', skipOffstage: false), findsOneWidget);
    expect(find.text('31', skipOffstage: false), findsOneWidget);
  });

  testWidgets('tapping a chip sets the value and Save records it',
      (tester) async {
    await pump(tester, const BackupSettings());
    await tester.tap(find.text('Every 7 days'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake!.periodCalls, [1]);
    expect(
      find.text('How often Anchor makes an automatic backup'),
      findsNothing, // dialog closed
    );
  });

  testWidgets('Cancel closes the period dialog without saving', (tester) async {
    await pump(tester, const BackupSettings());
    await tester.tap(find.text('Every 7 days'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fake!.periodCalls, isEmpty);
  });

  testWidgets('the keep-files dialog has no chips and Save records it',
      (tester) async {
    await pump(tester, const BackupSettings());
    await tester.tap(find.text('Keep 3 files'));
    await tester.pumpAndSettle();

    expect(find.text('Daily'), findsNothing);
    expect(find.text('How many backups to keep before the oldest is removed'),
        findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // No change made -> current value is saved back.
    expect(fake!.keepCalls, [3]);
  });
}
