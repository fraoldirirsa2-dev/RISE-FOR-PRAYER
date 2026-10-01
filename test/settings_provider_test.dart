import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/providers/settings_provider.dart';
import 'package:rise_for_prayer/screens/settings_screen.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'defaults fresh installs to Amharic and preserves saved English',
    () async {
      SharedPreferences.setMockInitialValues({});
      final freshSettings = SettingsProvider();
      await Future<void>.delayed(Duration.zero);
      expect(freshSettings.language, 'eth');
      freshSettings.dispose();

      SharedPreferences.setMockInitialValues({'language': 'en'});
      final existingSettings = SettingsProvider();
      await Future<void>.delayed(Duration.zero);
      expect(existingSettings.language, 'en');
      existingSettings.dispose();
    },
  );

  testWidgets('Settings shows localized appearance choices by default', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Both'), findsNothing);
    expect(find.text('Night Mode'), findsNothing);
    expect(find.text('ብርሃን'), findsOneWidget);
    expect(find.text('ጨለማ'), findsOneWidget);
    expect(find.text('System'), findsNothing);
    expect(find.text('Automatic'), findsNothing);
  });

  test(
    'enabling all reminders restores every individual reminder choice',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      await Future<void>.delayed(Duration.zero);

      settings.toggleReminder(2);
      await Future<void>.delayed(Duration.zero);
      expect(settings.reminderEnabled[2], isFalse);

      settings.toggleAllReminders(false);
      expect(settings.remindersEnabled, isFalse);
      expect(settings.reminderEnabled[2], isFalse);

      await settings.toggleAllReminders(true);
      expect(settings.remindersEnabled, isTrue);
      expect(settings.reminderEnabled, everyElement(isTrue));
      settings.dispose();
    },
  );
}
