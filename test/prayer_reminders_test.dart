import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rise_for_prayer/data/prayer_reminders.dart';
import 'package:rise_for_prayer/services/notification_service.dart';

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
}
