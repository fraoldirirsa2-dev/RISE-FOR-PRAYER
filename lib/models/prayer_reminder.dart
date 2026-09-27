class PrayerReminder {
  const PrayerReminder({
    required this.id,
    required this.amharicTitle,
    required this.englishTitle,
    required this.hour,
    required this.minute,
  });

  final int id;
  final String amharicTitle;
  final String englishTitle;
  final int hour;
  final int minute;

  String titleFor(String language) {
    return language == 'eth' ? amharicTitle : englishTitle;
  }
}
