import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rise_for_prayer/data/prayer_reminders.dart';
import 'package:rise_for_prayer/providers/settings_provider.dart';
import 'package:rise_for_prayer/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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

  test(
    'has explicit reminder offsets with backwards-compatible minute values',
    () {
      expect(PrayerReminderOffset.atPrayerTime.duration, Duration.zero);
      expect(
        PrayerReminderOffset.fiveMinutes.duration,
        const Duration(minutes: 5),
      );
      expect(
        PrayerReminderOffset.tenMinutes.duration,
        const Duration(minutes: 10),
      );
      expect(
        PrayerReminderOffset.fifteenMinutes.duration,
        const Duration(minutes: 15),
      );

      expect(
        PrayerReminderOffset.fromMinutes(0),
        PrayerReminderOffset.atPrayerTime,
      );
      expect(
        PrayerReminderOffset.fromMinutes(5),
        PrayerReminderOffset.fiveMinutes,
      );
      expect(
        PrayerReminderOffset.fromMinutes(10),
        PrayerReminderOffset.tenMinutes,
      );
      expect(
        PrayerReminderOffset.fromMinutes(15),
        PrayerReminderOffset.fifteenMinutes,
      );
    },
  );

  test('uses an existing Android notification icon resource', () {
    final iconFile = File(
      'android/app/src/main/res/drawable/ic_notification.xml',
    );
    final keepFile = File('android/app/src/main/res/raw/keep.xml');

    expect(
      iconFile.existsSync(),
      isTrue,
      reason: 'The Android notification icon resource must exist.',
    );
    expect(
      keepFile.readAsStringSync(),
      contains('@drawable/ic_notification'),
      reason: 'Resource shrinking must preserve the runtime-loaded icon.',
    );
    expect(NotificationService.androidNotificationIconName, 'ic_notification');
  });

  test('calculates each reminder offset before a morning prayer', () {
    tz_data.initializeTimeZones();
    final location = tz.getLocation('Africa/Addis_Ababa');
    final now = tz.TZDateTime(location, 2026, 10, 1, 5, 0);
    final expected = {
      15: tz.TZDateTime(location, 2026, 10, 1, 5, 45),
      10: tz.TZDateTime(location, 2026, 10, 1, 5, 50),
      5: tz.TZDateTime(location, 2026, 10, 1, 5, 55),
      0: tz.TZDateTime(location, 2026, 10, 1, 6, 0),
    };

    for (final entry in expected.entries) {
      expect(
        nextPrayerReminderDate(
          location: location,
          now: now,
          hour: 6,
          minute: 0,
          offsetMinutes: entry.key,
        ),
        entry.value,
      );
    }
  });

  test('keeps offsets before a midnight prayer on the previous evening', () {
    tz_data.initializeTimeZones();
    final location = tz.getLocation('Africa/Addis_Ababa');
    final now = tz.TZDateTime(location, 2026, 10, 1, 23, 30);
    final expected = {
      15: tz.TZDateTime(location, 2026, 10, 1, 23, 45),
      10: tz.TZDateTime(location, 2026, 10, 1, 23, 50),
      5: tz.TZDateTime(location, 2026, 10, 1, 23, 55),
      0: tz.TZDateTime(location, 2026, 10, 2, 0, 0),
    };

    for (final entry in expected.entries) {
      expect(
        nextPrayerReminderDate(
          location: location,
          now: now,
          hour: 0,
          minute: 0,
          offsetMinutes: entry.key,
        ),
        entry.value,
      );
    }
  });

  test(
    'moves a passed reminder to the next day without skipping valid ones',
    () {
      tz_data.initializeTimeZones();
      final location = tz.getLocation('Africa/Addis_Ababa');
      final now = tz.TZDateTime(location, 2026, 10, 1, 5, 52);
      final expected = {
        15: tz.TZDateTime(location, 2026, 10, 2, 5, 45),
        10: tz.TZDateTime(location, 2026, 10, 2, 5, 50),
        5: tz.TZDateTime(location, 2026, 10, 1, 5, 55),
        0: tz.TZDateTime(location, 2026, 10, 1, 6, 0),
      };

      for (final entry in expected.entries) {
        expect(
          nextPrayerReminderDate(
            location: location,
            now: now,
            hour: 6,
            minute: 0,
            offsetMinutes: entry.key,
          ),
          entry.value,
        );
      }
    },
  );

  test('keeps one stable notification id per prayer hour across offsets', () {
    expect(NotificationService.notificationId(0), prayerReminders[0].id);
    expect(NotificationService.notificationId(0, 0), prayerReminders[0].id);
    expect(NotificationService.notificationId(0, 5), prayerReminders[0].id);
    expect(NotificationService.notificationId(0, 10), prayerReminders[0].id);
    expect(NotificationService.notificationId(0, 15), prayerReminders[0].id);

    expect(NotificationService.notificationId(6), prayerReminders[6].id);
    expect(NotificationService.notificationId(6, 15), prayerReminders[6].id);
  });
}
