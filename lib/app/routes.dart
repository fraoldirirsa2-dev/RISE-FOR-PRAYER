import 'package:flutter/material.dart';
import 'package:rise_for_prayer/screens/home_screen.dart';
import 'package:rise_for_prayer/screens/onboarding_screen.dart';
import 'package:rise_for_prayer/screens/calendar_screen.dart';
import 'package:rise_for_prayer/screens/settings_screen.dart';
import 'package:rise_for_prayer/features/analysis/screens/analysis_screen.dart';
import 'package:rise_for_prayer/features/bible/models/bible_models.dart';
import 'package:rise_for_prayer/features/bible/screens/bible_screen.dart';
import 'package:rise_for_prayer/features/weekly_prayer_rule/weekly_prayer_rule.dart';

class AppRoutes {
  static const String home = '/home';
  static const String onboarding = '/onboarding';
  static const String prayerSession = '/prayer-session';
  static const String calendar = '/calendar';
  static const String settings = '/settings';
  static const String analysis = '/analysis';
  static const String bible = '/bible';
  static const String weeklyPrayerRule = '/weekly-prayer-rule';

  static Map<String, WidgetBuilder> get routes => {
    home: (context) => const HomeScreen(),
    onboarding: (context) => const OnboardingScreen(),
    prayerSession: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final day = args is Map ? args['day'] : null;
      final hour = args is Map ? args['hour'] : args;
      return RuleSessionScreen(
        day: day is int ? day.clamp(0, 6).toInt() : DateTime.now().weekday - 1,
        hour: hour is int ? hour.clamp(0, 6).toInt() : 0,
      );
    },
    calendar: (context) => const CalendarScreen(),
    settings: (context) => const SettingsScreen(),
    analysis: (context) => const AnalysisScreen(),
    bible: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      return BibleScreen(
        initialReference: args is BibleReference ? args : null,
      );
    },
    weeklyPrayerRule: (context) => const WeeklyPrayerRuleScreen(),
  };
}
