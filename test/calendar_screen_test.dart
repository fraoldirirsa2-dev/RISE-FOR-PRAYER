import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rise_for_prayer/providers/calendar_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/providers/settings_provider.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:rise_for_prayer/screens/calendar_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'standalone Calendar opens and supports mode and Today controls',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => SettingsProvider()),
            calendarProvider.overrideWith((ref) => CalendarProvider()),
          ],
          child: const MaterialApp(home: CalendarScreen()),
        ),
      );
      await tester.pump();

      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.byTooltip('Today'), findsOneWidget);
      expect(find.text('Gregorian'), findsOneWidget);
      expect(find.text('Ethiopic'), findsOneWidget);

      await tester.tap(find.text('Ethiopic'));
      await tester.pump();
      expect(find.text('Ethiopic'), findsOneWidget);

      await tester.tap(find.byTooltip('Today'));
      await tester.pump();
      expect(find.byTooltip('Today'), findsOneWidget);
    },
  );

  test('Today follows midnight until another date is selected', () {
    final provider = CalendarProvider();
    final firstDay = DateTime(2026, 9, 12, 23, 59);
    provider.syncToday(firstDay);

    provider.syncToday(DateTime(2026, 9, 13, 0, 1));
    expect(provider.selectedDate, DateTime(2026, 9, 13));

    provider.selectDate(DateTime(2026, 9, 20));
    provider.syncToday(DateTime(2026, 9, 14));
    expect(provider.selectedDate, DateTime(2026, 9, 20));

    provider.dispose();
  });
}
