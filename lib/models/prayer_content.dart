import 'package:rise_for_prayer/features/bible/models/bible_models.dart';

class PrayerSection {
  const PrayerSection({
    required this.title,
    required this.amharic,
    required this.english,
  });

  final String title;
  final String amharic;
  final String english;
}

class PrayerReading {
  const PrayerReading({
    required this.sections,
    this.readings = const [],
    this.dailyReadings = const [],
  });

  final List<PrayerSection> sections;
  final List<BibleReference> readings;
  final List<BibleReference> dailyReadings;
}
