import 'package:flutter_test/flutter_test.dart';
import 'package:rise_for_prayer/data/prayer_reminders.dart';

void main() {
  test('defines seven stable daily reminders from prayer data', () {
    expect(prayerReminders, hasLength(7));
    expect(prayerReminders.map((reminder) => reminder.id), [
      1002,
      1003,
      1004,
      1005,
      1006,
      1007,
      1001,
    ]);
    expect(
      prayerReminders.every(
        (reminder) =>
            reminder.hour >= 0 &&
            reminder.hour < 24 &&
            reminder.minute >= 0 &&
            reminder.minute < 60,
      ),
      isTrue,
    );
  });
}
