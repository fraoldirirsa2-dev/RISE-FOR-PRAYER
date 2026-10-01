import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/prayer_document.dart';

class PrayerRepository {
  const PrayerRepository();

  Future<PrayerDocument> loadDailyPrayer() async {
    final jsonString = await rootBundle.loadString(
      'assets/data/daily_prayer.json',
    );

    final json = jsonDecode(jsonString);

    return PrayerDocument.fromJson(Map<String, dynamic>.from(json));
  }
}
