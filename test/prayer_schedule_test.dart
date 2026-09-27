import 'package:flutter_test/flutter_test.dart';
import 'package:rise_for_prayer/features/prayer_hours/data/canonical_prayer_hours.dart';
import 'package:rise_for_prayer/features/prayer_hours/domain/prayer_schedule.dart';

void main() {
  const schedule = PrayerSchedule(canonicalPrayerHours);

  test('finds Midnight as the next prayer late at night', () {
    final next = schedule.next(DateTime(2026, 9, 11, 23, 59));

    expect(next.prayerHour.prayerId, 'midnight');
    expect(next.at, DateTime(2026, 9, 12));
  });

  test('keeps the previous canonical hour current across midnight', () {
    final current = schedule.current(DateTime(2026, 9, 11, 0, 1));

    expect(current.prayerHour.prayerId, 'midnight');
    expect(current.at, DateTime(2026, 9, 11));
  });

  test('uses a stable reader mapping for notification deep links', () {
    final morning = canonicalPrayerHours.firstWhere(
      (hour) => hour.prayerId == 'morning',
    );

    expect(morning.readerIndex, 0);
    expect(morning.hour, 6);
  });

  test('follows the clock for current and next prayer throughout the day', () {
    final expectations = <DateTime, List<String>>{
      DateTime(2026, 9, 12, 0, 0): ['midnight', 'morning'],
      DateTime(2026, 9, 12, 1, 0): ['midnight', 'morning'],
      DateTime(2026, 9, 12, 5, 59): ['midnight', 'morning'],
      DateTime(2026, 9, 12, 6, 0): ['morning', 'third'],
      DateTime(2026, 9, 12, 7, 30): ['morning', 'third'],
      DateTime(2026, 9, 12, 8, 59): ['morning', 'third'],
      DateTime(2026, 9, 12, 9, 0): ['third', 'sixth'],
      DateTime(2026, 9, 12, 12, 0): ['sixth', 'ninth'],
      DateTime(2026, 9, 12, 13, 30): ['sixth', 'ninth'],
      DateTime(2026, 9, 12, 15, 0): ['ninth', 'vespers'],
      DateTime(2026, 9, 12, 18, 0): ['vespers', 'compline'],
      DateTime(2026, 9, 12, 19, 30): ['vespers', 'compline'],
      DateTime(2026, 9, 12, 21, 0): ['compline', 'midnight'],
      DateTime(2026, 9, 12, 22, 0): ['compline', 'midnight'],
      DateTime(2026, 9, 12, 23, 59): ['compline', 'midnight'],
    };

    for (final entry in expectations.entries) {
      expect(schedule.current(entry.key).prayerHour.prayerId, entry.value[0]);
      expect(schedule.next(entry.key).prayerHour.prayerId, entry.value[1]);
    }
  });

  test('updates statuses around the current prayer', () {
    final now = DateTime(2026, 9, 12, 19, 30);
    final occurrences = schedule.occurrencesForDate(now);
    final tomorrow = schedule.occurrencesForDate(
      now.add(const Duration(days: 1)),
    );

    PrayerStatus statusFor(String prayerId, {bool nextDay = false}) =>
        schedule.statusFor(
          (nextDay ? tomorrow : occurrences).firstWhere(
            (occurrence) => occurrence.prayerHour.prayerId == prayerId,
          ),
          now,
        );

    expect(statusFor('ninth'), PrayerStatus.completed);
    expect(statusFor('vespers'), PrayerStatus.current);
    expect(statusFor('compline'), PrayerStatus.upcoming);
    expect(statusFor('midnight', nextDay: true), PrayerStatus.upcoming);
  });
}
