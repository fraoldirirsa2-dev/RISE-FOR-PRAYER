import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rise_for_prayer/data/prayer_data.dart';
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

  test('includes a localized Scripture reminder for each prayer hour', () {
    const amharicReferences = [
      'መዝሙር 118:24',
      'ኢሳይያስ 40:31',
      'መዝሙር 37:3',
      'መዝሙር 121:5-6',
      'መዝሙር 92:2',
      'መዝሙር 4:8',
      'መዝሙር 119:62',
    ];
    const englishReferences = [
      'Psalm 118:24',
      'Isaiah 40:31',
      'Psalm 37:3',
      'Psalm 121:5-6',
      'Psalm 92:2',
      'Psalm 4:8',
      'Psalm 119:62',
    ];

    for (
      var prayerIndex = 0;
      prayerIndex < prayerReminders.length;
      prayerIndex++
    ) {
      final reminder = prayerReminders[prayerIndex];
      final englishBody = NotificationService.prayerReminderBody(
        language: 'en',
        amharicTitle: reminder.amharicTitle,
        englishTitle: reminder.englishTitle,
        prayerIndex: prayerIndex,
        offset: PrayerReminderOffset.atPrayerTime,
      ).split('|').first;
      final amharicBody = NotificationService.prayerReminderBody(
        language: 'eth',
        amharicTitle: reminder.amharicTitle,
        englishTitle: reminder.englishTitle,
        prayerIndex: prayerIndex,
        offset: PrayerReminderOffset.atPrayerTime,
      ).split('|').first;

      expect(englishBody, contains(englishReferences[prayerIndex]));
      expect(amharicBody, contains(amharicReferences[prayerIndex]));
      expect(englishBody, contains('Make time for prayer'));
      expect(amharicBody, contains('ለጸሎት ጊዜ ይለዩ'));
      expect(englishBody, contains('has arrived'));
      expect(amharicBody, contains('አሁን ደርሷል'));
    }
  });

  test('keeps the prayer-specific verse in advance reminders', () {
    final vespers = prayerReminders[4];
    final englishBody = NotificationService.prayerReminderBody(
      language: 'en',
      amharicTitle: vespers.amharicTitle,
      englishTitle: vespers.englishTitle,
      prayerIndex: 4,
      offset: PrayerReminderOffset.tenMinutes,
    ).split('|').first;
    final amharicBody = NotificationService.prayerReminderBody(
      language: 'eth',
      amharicTitle: vespers.amharicTitle,
      englishTitle: vespers.englishTitle,
      prayerIndex: 4,
      offset: PrayerReminderOffset.tenMinutes,
    ).split('|').first;

    expect(englishBody, contains('in 10 minutes'));
    expect(englishBody, contains('Psalm 92:2'));
    expect(amharicBody, contains('በ10 ደቂቃ ውስጥ'));
    expect(amharicBody, contains('መዝሙር 92:2'));
  });

  test('uses updated prayer labels and Vespers display time', () {
    expect(hours.map((hour) => hour.ge).toList(), [
      'ነግህ',
      'ሠለስት',
      'ቀትር',
      'ተሰዓት',
      'ሠርክ',
      'ንዋም',
      'መንፈቀ ሌሊት',
    ]);
    expect(hours[4].time, '5:00 PM');
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
