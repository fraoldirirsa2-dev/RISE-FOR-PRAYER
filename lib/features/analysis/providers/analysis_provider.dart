import 'package:flutter/foundation.dart';
import 'package:rise_for_prayer/features/analysis/models/analysis_models.dart';
import 'package:rise_for_prayer/features/analysis/services/analysis_service.dart';
import 'package:rise_for_prayer/providers/prayer_provider.dart';
import 'package:rise_for_prayer/services/time_service.dart';

class AnalysisProvider extends ChangeNotifier {
  AnalysisProvider({AnalysisService? service})
    : _service = service ?? const AnalysisService();

  final AnalysisService _service;
  int _rangeDays = 7;
  PrayerAnalysisSummary _summary = const PrayerAnalysisSummary(
    rangeDays: 7,
    dailyStatistics: [],
    prayerPerformance: [],
    currentStreak: 0,
    bestStreak: 0,
    bestDay: null,
  );

  int get rangeDays => _rangeDays;
  PrayerAnalysisSummary get summary => _summary;

  void setRange(int days, PrayerProvider prayerProvider) {
    if (![7, 30, 90, 365].contains(days) || days == _rangeDays) return;
    _rangeDays = days;
    _recalculate(prayerProvider);
  }

  void update(PrayerProvider prayerProvider) {
    _recalculate(prayerProvider);
  }

  void _recalculate(PrayerProvider prayerProvider, {bool notify = true}) {
    _summary = _service.calculate(
      history: prayerProvider.history,
      today: TimeService.currentNow(),
      rangeDays: _rangeDays,
    );
    if (notify) notifyListeners();
  }
}
