import 'package:flutter_test/flutter_test.dart';
import 'package:rise_for_prayer/features/analysis/services/analysis_service.dart';

void main() {
  const service = AnalysisService();
  final today = DateTime(2026, 9, 7);
  final fullDay = List<bool>.filled(7, true);

  test('empty history has no completed prayers or best day', () {
    final summary = service.calculate(
      history: const {},
      today: today,
      rangeDays: 7,
    );

    expect(summary.totalCompleted, 0);
    expect(summary.totalExpected, 49);
    expect(summary.completionRate, 0);
    expect(summary.bestDay, isNull);
    expect(summary.currentStreak, 0);
  });

  test('partial and complete days calculate rates from real records', () {
    final summary = service.calculate(
      history: {
        '2026-09-07': [true, ...List<bool>.filled(6, false)],
        '2026-09-06': fullDay,
      },
      today: today,
      rangeDays: 7,
    );

    expect(summary.totalCompleted, 8);
    expect(summary.completionRate, closeTo(8 / 49, 0.000001));
    expect(summary.prayerPerformance.first.completed, 2);
    expect(summary.prayerPerformance.first.rate, closeTo(2 / 7, 0.000001));
  });

  test('current and best streaks stop at an incomplete day', () {
    final summary = service.calculate(
      history: {
        '2026-09-03': fullDay,
        '2026-09-04': fullDay,
        '2026-09-05': List<bool>.filled(7, false),
        '2026-09-06': fullDay,
        '2026-09-07': fullDay,
      },
      today: today,
      rangeDays: 7,
    );

    expect(summary.currentStreak, 2);
    expect(summary.bestStreak, 2);
    expect(summary.bestDay?.completed, 7);
  });
}
