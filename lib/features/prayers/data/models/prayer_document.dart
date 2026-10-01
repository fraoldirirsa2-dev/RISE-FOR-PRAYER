class PrayerDocument {
  final String id;
  final Map<String, String> title;
  final List<PrayerSection> sections;

  const PrayerDocument({
    required this.id,
    required this.title,
    required this.sections,
  });

  factory PrayerDocument.fromJson(Map<String, dynamic> json) {
    return PrayerDocument(
      id: json['id'] as String,
      title: Map<String, String>.from(json['title'] as Map),
      sections: (json['sections'] as List)
          .map(
            (item) => PrayerSection.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class PrayerSection {
  final String id;
  final String english;
  final String amharic;

  const PrayerSection({
    required this.id,
    required this.english,
    required this.amharic,
  });

  factory PrayerSection.fromJson(Map<String, dynamic> json) {
    return PrayerSection(
      id: json['id'] as String,
      english: json['english'] as String,
      amharic: json['amharic'] as String,
    );
  }
}
