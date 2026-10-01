import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/features/analysis/screens/analysis_screen.dart';
import 'package:rise_for_prayer/providers/prayer_provider.dart';
import 'package:rise_for_prayer/providers/settings_provider.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('analysis starts empty and updates after a completion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final prayer = PrayerProvider();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerProvider.overrideWith((ref) => prayer),
          settingsProvider.overrideWith((ref) => SettingsProvider()),
        ],
        child: const MaterialApp(home: AnalysisScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('No prayer history yet'), findsOneWidget);

    prayer.toggleHour(0);
    await tester.pump();

    expect(find.text('1 / 7'), findsOneWidget);
    expect(find.text('14%'), findsWidgets);

    await tester.tap(find.text('30D'));
    await tester.pump();
    expect(find.text('30D'), findsOneWidget);
  });
}
