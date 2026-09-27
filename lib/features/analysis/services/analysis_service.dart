import 'package:rise_for_prayer/data/prayer_data.dart';
import 'package:rise_for_prayer/features/analysis/models/analysis_models.dart';

class AnalysisService {
  const AnalysisService();

  PrayerAnalysisSummary calculate({
    required Map<String, List<bool>> history,
    required DateTime today,
    required int rangeDays,
  }) {
    final normalizedToday = _dayOnly(today);
    final firstDay = normalizedToday.subtract(Duration(days: rangeDays - 1));
    final dailyStatistics = List.generate(rangeDays, (index) {
      final date = firstDay.add(Duration(days: index));
      final completions = history[_key(date)] ?? const <bool>[];
      final completed = completions.where((value) => value).length;
      return DailyPrayerStatistic(date: date, completed: completed, total: 7);
    });

    final performance = List.generate(hours.length, (index) {
      var completed = 0;
      for (final day in dailyStatistics) {
        final values = history[_key(day.date)] ?? const <bool>[];
        if (index < values.length && values[index]) completed++;
      }
      return PrayerPerformance(
        prayerId: hours[index].en,
        completed: completed,
        expected: rangeDays,
      );
    });

    return PrayerAnalysisSummary(
      rangeDays: rangeDays,
      dailyStatistics: dailyStatistics,
      prayerPerformance: performance,
      currentStreak: _streakFrom(normalizedToday, history),
      bestStreak: _bestStreak(normalizedToday, history),
      bestDay: _bestDay(dailyStatistics),
    );
  }

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool _isComplete(DateTime date, Map<String, List<bool>> history) {
    final values = history[_key(date)];
    return values != null &&
        values.length >= 7 &&
        values.take(7).every((value) => value);
  }

  int _streakFrom(DateTime date, Map<String, List<bool>> history) {
    var streak = 0;
    var cursor = date;
    while (_isComplete(cursor, history)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _bestStreak(DateTime today, Map<String, List<bool>> history) {
    if (history.isEmpty) return 0;
    final dates = history.keys.map(DateTime.parse).toList()..sort();
    var cursor = dates.first;
    var best = 0;
    var streak = 0;
    while (!cursor.isAfter(today)) {
      if (_isComplete(cursor, history)) {
        streak++;
        if (streak > best) best = streak;
      } else {
        streak = 0;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return best;
  }

  DailyPrayerStatistic? _bestDay(List<DailyPrayerStatistic> days) {
    final withHistory = days.where((day) => day.completed > 0).toList();
    if (withHistory.isEmpty) return null;
    return withHistory.reduce(
      (best, day) => day.completed > best.completed ? day : best,
    );
  }
}
