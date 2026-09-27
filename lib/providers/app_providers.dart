import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/features/bible/providers/bible_provider.dart';
import 'package:rise_for_prayer/features/bible/providers/daily_scripture_provider.dart';
import 'package:rise_for_prayer/features/analysis/providers/analysis_provider.dart';
import 'package:rise_for_prayer/providers/calendar_provider.dart';
import 'package:rise_for_prayer/providers/prayer_provider.dart';
import 'package:rise_for_prayer/providers/settings_provider.dart';
import 'package:rise_for_prayer/services/time_service.dart';

final settingsProvider = ChangeNotifierProvider<SettingsProvider>((ref) {
  return SettingsProvider();
});

final prayerProvider = ChangeNotifierProvider<PrayerProvider>((ref) {
  return PrayerProvider();
});

final analysisProvider = ChangeNotifierProvider<AnalysisProvider>((ref) {
  final analysis = AnalysisProvider();
  analysis.update(ref.watch(prayerProvider));
  return analysis;
});

final calendarProvider = ChangeNotifierProvider<CalendarProvider>((ref) {
  return CalendarProvider();
});

final timeServiceProvider = ChangeNotifierProvider<TimeService>((ref) {
  return TimeService();
});

final bibleProvider = ChangeNotifierProvider<BibleProvider>((ref) {
  return BibleProvider();
});

final dailyScriptureProvider = ChangeNotifierProvider<DailyScriptureProvider>((
  ref,
) {
  return DailyScriptureProvider();
});
