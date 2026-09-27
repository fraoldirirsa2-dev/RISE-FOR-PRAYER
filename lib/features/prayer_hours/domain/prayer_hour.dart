/// A canonical prayer hour, independent from presentation text or storage.
///
/// [prayerId] is the stable identifier used in routes and notification
/// payloads. [readerIndex] temporarily maps the hour to the bundled prayer
/// content while that content is migrated to ID-based lookups.
class PrayerHour {
  const PrayerHour({
    required this.prayerId,
    required this.readerIndex,
    required this.order,
    required this.titleAmharic,
    required this.titleEnglish,
    required this.descriptionAmharic,
    required this.descriptionEnglish,
    required this.hour,
    required this.minute,
    required this.icon,
    this.enabled = true,
    this.reminderEnabled = true,
    this.reminderOffset = Duration.zero,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  }) : assert(hour >= 0 && hour <= 23),
       assert(minute >= 0 && minute <= 59),
       assert(order > 0),
       assert(readerIndex >= 0);

  final String prayerId;
  final int readerIndex;
  final int order;
  final String titleAmharic;
  final String titleEnglish;
  final String descriptionAmharic;
  final String descriptionEnglish;
  final int hour;
  final int minute;
  final String icon;
  final bool enabled;
  final bool reminderEnabled;
  final Duration reminderOffset;
  final bool soundEnabled;
  final bool vibrationEnabled;

  String titleFor(String language) =>
      language == 'eth' ? titleAmharic : titleEnglish;

  PrayerHour copyWith({
    bool? enabled,
    bool? reminderEnabled,
    Duration? reminderOffset,
    bool? soundEnabled,
    bool? vibrationEnabled,
    int? hour,
    int? minute,
  }) => PrayerHour(
    prayerId: prayerId,
    readerIndex: readerIndex,
    order: order,
    titleAmharic: titleAmharic,
    titleEnglish: titleEnglish,
    descriptionAmharic: descriptionAmharic,
    descriptionEnglish: descriptionEnglish,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    icon: icon,
    enabled: enabled ?? this.enabled,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderOffset: reminderOffset ?? this.reminderOffset,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
  );
}
