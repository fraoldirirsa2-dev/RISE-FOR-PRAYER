class DailyPrayerStatistic {
  const DailyPrayerStatistic({
    required this.date,
    required this.completed,
    required this.total,
  });

  final DateTime date;
  final int completed;
  final int total;

  double get rate => total == 0 ? 0 : completed / total;
}

class PrayerPerformance {
  const PrayerPerformance({
    required this.prayerId,
    required this.completed,
    required this.expected,
  });

  final String prayerId;
  final int completed;
  final int expected;

  double get rate => expected == 0 ? 0 : completed / expected;
}

class PrayerAnalysisSummary {
  const PrayerAnalysisSummary({
    required this.rangeDays,
    required this.dailyStatistics,
    required this.prayerPerformance,
    required this.currentStreak,
    required this.bestStreak,
    required this.bestDay,
  });

  final int rangeDays;
  final List<DailyPrayerStatistic> dailyStatistics;
  final List<PrayerPerformance> prayerPerformance;
  final int currentStreak;
  final int bestStreak;
  final DailyPrayerStatistic? bestDay;

  int get totalExpected =>
      dailyStatistics.fold(0, (sum, day) => sum + day.total);
  int get totalCompleted =>
      dailyStatistics.fold(0, (sum, day) => sum + day.completed);
  double get completionRate =>
      totalExpected == 0 ? 0 : totalCompleted / totalExpected;

  bool get hasHistory => totalCompleted > 0;
}
