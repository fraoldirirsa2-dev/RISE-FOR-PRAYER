import 'package:rise_for_prayer/features/prayer_hours/domain/prayer_hour.dart';

class ScheduledPrayerHour {
  const ScheduledPrayerHour({required this.prayerHour, required this.at});

  final PrayerHour prayerHour;
  final DateTime at;

  Duration remainingFrom(DateTime now) => at.difference(now);
}

enum PrayerStatus { upcoming, current, completed, missed }

class PrayerOccurrence {
  const PrayerOccurrence({required this.prayerHour, required this.at});

  final PrayerHour prayerHour;
  final DateTime at;

  DateTime get localDate => DateTime(at.year, at.month, at.day);
}

/// Pure schedule calculation, suitable for unit tests and future custom times.
class PrayerSchedule {
  const PrayerSchedule(this.hours);

  final List<PrayerHour> hours;

  List<ScheduledPrayerHour> forDate(DateTime date) =>
      hours
          .where((hour) => hour.enabled)
          .map(
            (hour) => ScheduledPrayerHour(
              prayerHour: hour,
              at: DateTime(
                date.year,
                date.month,
                date.day,
                hour.hour,
                hour.minute,
              ),
            ),
          )
          .toList()
        ..sort((a, b) => a.at.compareTo(b.at));

  List<PrayerOccurrence> occurrencesForDate(DateTime date) => forDate(date)
      .map(
        (scheduled) => PrayerOccurrence(
          prayerHour: scheduled.prayerHour,
          at: scheduled.at,
        ),
      )
      .toList(growable: false);

  ScheduledPrayerHour next(DateTime now) {
    final today = forDate(now);
    for (final prayer in today) {
      if (prayer.at.isAfter(now)) return prayer;
    }
    final tomorrow = forDate(now.add(const Duration(days: 1)));
    if (tomorrow.isEmpty) throw StateError('Prayer schedule is empty.');
    return tomorrow.first;
  }

  ScheduledPrayerHour current(DateTime now) {
    final today = forDate(now);
    final candidates = today;
    if (candidates.isEmpty) throw StateError('Prayer schedule is empty.');
    final current = candidates.where((prayer) => !prayer.at.isAfter(now));
    return current.isEmpty ? candidates.last : current.last;
  }

  PrayerStatus statusFor(PrayerOccurrence occurrence, DateTime now) {
    final date = occurrence.localDate;
    final today = DateTime(now.year, now.month, now.day);
    if (date.isAfter(today)) return PrayerStatus.upcoming;
    if (date.isBefore(today)) return PrayerStatus.missed;
    if (occurrence.at.isAfter(now)) return PrayerStatus.upcoming;
    final latestElapsed = occurrencesForDate(date)
        .where((candidate) => !candidate.at.isAfter(now))
        .last;
    return latestElapsed.at == occurrence.at
        ? PrayerStatus.current
        : PrayerStatus.completed;
  }
}
