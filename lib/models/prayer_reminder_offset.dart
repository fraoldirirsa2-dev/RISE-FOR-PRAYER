enum PrayerReminderOffset {
  atPrayerTime,
  fiveMinutes,
  tenMinutes,
  fifteenMinutes;

  Duration get duration {
    switch (this) {
      case PrayerReminderOffset.atPrayerTime:
        return Duration.zero;
      case PrayerReminderOffset.fiveMinutes:
        return const Duration(minutes: 5);
      case PrayerReminderOffset.tenMinutes:
        return const Duration(minutes: 10);
      case PrayerReminderOffset.fifteenMinutes:
        return const Duration(minutes: 15);
    }
  }

  int get minutes => duration.inMinutes;

  static PrayerReminderOffset fromMinutes(int minutes) {
    switch (minutes) {
      case 0:
        return PrayerReminderOffset.atPrayerTime;
      case 5:
        return PrayerReminderOffset.fiveMinutes;
      case 10:
        return PrayerReminderOffset.tenMinutes;
      case 15:
        return PrayerReminderOffset.fifteenMinutes;
      default:
        return PrayerReminderOffset.atPrayerTime;
    }
  }

  String label(String language) {
    if (language == 'en') {
      switch (this) {
        case PrayerReminderOffset.atPrayerTime:
          return 'At prayer time';
        case PrayerReminderOffset.fiveMinutes:
          return '5 minutes before';
        case PrayerReminderOffset.tenMinutes:
          return '10 minutes before';
        case PrayerReminderOffset.fifteenMinutes:
          return '15 minutes before';
      }
    }

    switch (this) {
      case PrayerReminderOffset.atPrayerTime:
        return 'በጸሎት ሰዓት';
      case PrayerReminderOffset.fiveMinutes:
        return '5 ደቂቃ በፊት';
      case PrayerReminderOffset.tenMinutes:
        return '10 ደቂቃ በፊት';
      case PrayerReminderOffset.fifteenMinutes:
        return '15 ደቂቃ በፊት';
    }
  }
}
