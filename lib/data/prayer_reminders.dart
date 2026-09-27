import 'package:rise_for_prayer/data/prayer_data.dart';
import 'package:rise_for_prayer/models/prayer_reminder.dart';

const _notificationIdsByReaderIndex = <int, int>{
  0: 1002, // Morning
  1: 1003, // Third hour
  2: 1004, // Sixth hour
  3: 1005, // Ninth hour
  4: 1006, // Vespers
  5: 1007, // Compline
  6: 1001, // Midnight
};

/// Stable notification identifiers. Never derive these from list position;
/// scheduled platform notifications must survive reordering of the UI.
final prayerReminders = hours
    .map((hour) {
      // 1. Safe parsing defaults
      int hourOfDay = 0;
      int minute = 0;

      try {
        // Basic validation to ensure the string can be split safely
        final cleanTime = hour.time.trim().toUpperCase();
        final parts = cleanTime.split(' ');

        if (parts.length >= 2) {
          final clock = parts.first.split(':');
          hourOfDay = int.parse(clock[0]);
          minute = clock.length > 1 ? int.parse(clock[1]) : 0;

          final period = parts.last;
          if (period == 'PM' && hourOfDay != 12) hourOfDay += 12;
          if (period == 'AM' && hourOfDay == 12) hourOfDay = 0;
        }
      } catch (e) {
        // If parsing fails, it defaults to 00:00 instead of crashing the app.
        // In a real app, you might want to log this error.
      }

      return PrayerReminder(
        // 2. Safe map lookup with a fallback ID to prevent null crashes
        id: _notificationIdsByReaderIndex[hour.id] ?? (10000 + hour.id),
        amharicTitle: hour.ge,
        englishTitle: hour.en,
        hour: hourOfDay,
        minute: minute,
      );
    })
    .toList(growable: false);
