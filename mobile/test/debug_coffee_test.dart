import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anchor/features/settings/presentation/settings_screen.dart';
import 'package:anchor/l10n/app_localizations.dart';

void main() {
  testWidgets('debug coffee link', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    
    // Check if SettingsScreen is there
    expect(find.byType(SettingsScreen), findsOneWidget);
    
    // Check for any text
    final allText = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
    print('All text found: $allText');
    
    // Check for specific texts
    print('Support Anchor found: ${find.text('Support Anchor').evaluate().length}');
    print('Settings Help found: ${find.text('Settings').evaluate().length}');
    
    debugDefaultTargetPlatformOverride = null;
  });
}
