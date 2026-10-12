import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/app/app.dart';
import 'package:rise_for_prayer/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches to the splash and then onboarding on first run', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: RiseForPrayerApp()));

    expect(find.text('ለጸሎት ተነሱ'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 7000));
    await tester.pumpAndSettle();

    expect(find.text('ሰባቱ የጸሎት ሰዓታት'), findsOneWidget);
  });

  testWidgets('HomeScreen owns its live clock dependency', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );

    expect(find.text('ቀጣዩ የጸሎት ሰዓት'), findsOneWidget);
    expect(find.text('የሚቀረው ጊዜ'), findsOneWidget);
    expect(find.text('ቀጣዩን ጸሎት ይመልከቱ'), findsOneWidget);
  });
}
