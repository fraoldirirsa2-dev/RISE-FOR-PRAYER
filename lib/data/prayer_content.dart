import 'package:rise_for_prayer/models/prayer_content.dart';
import 'package:rise_for_prayer/features/bible/models/bible_models.dart';

import 'dart:math';

const prayerReadings = [
  PrayerReading(
    readings: [
      BibleReference.psalm(51),
      BibleReference.psalm(63),
      BibleReference.psalm(64),
      BibleReference.psalm(69),
      BibleReference.psalm(118),
    ],
    sections: [
      PrayerSection(
        title: 'Opening',
        amharic: 'በአብ፣ በወልድ፣ እና በመንፈስ ቅዱስ ስም። አሐዱ አምላክ። አሜን።',
        english: 'In the name of the Father, and of the Son, and of the Holy Spirit, one God. Amen.',
      ),
      PrayerSection(
        title: 'Prayer',
        amharic: 'እግዚኦ አምላኬ፣ በዚህ ሰዓት እንዲሰገድልኝ አግዝአለሁ።',
        english:
            'O Lord, my God, grant me grace to pray faithfully at this hour.',
      ),
    ],
  ),
  PrayerReading(
    readings: [
      BibleReference.psalm(51),
      BibleReference.psalm(62),
      BibleReference.psalm(66),
      BibleReference.psalm(67),
      BibleReference.psalm(148),
      BibleReference.psalm(149),
      BibleReference.psalm(150),
    ],
    sections: [
      PrayerSection(
        title: 'Opening',
        amharic: 'በአብ፣ በወልድ፣ እና በመንፈስ ቅዱስ ስም። አሜን።',
        english: 'In the name of the Father, and of the Son, and of the Holy Spirit. Amen.',
      ),
      PrayerSection(
        title: 'Hymn',
        amharic: 'ለአንተ ይገባል ምስጋና፣ ለአንተ ይገባል ክብር።',
        english: 'To You belongs praise; to You belongs glory and honor.',
      ),
    ],
  ),
  PrayerReading(
    readings: [
      BibleReference.psalm(51),
      BibleReference.psalm(19),
      BibleReference.psalm(20),
      BibleReference.psalm(21),
      BibleReference.psalm(22),
      BibleReference.psalm(23),
    ],
    sections: [
      PrayerSection(
        title: 'Opening',
        amharic: 'በአብ፣ በወልድ፣ እና በመንፈስ ቅዱስ ስም። አሜን።',
        english: 'In the name of the Father, and of the Son, and of the Holy Spirit. Amen.',
      ),
      PrayerSection(
        title: 'Gospel',
        amharic: 'ቃልህ ለእግሮቼ መብራት ነው፣ ለመንገዴም ብርሃን ነው።',
        english: 'Your word is a lamp to my feet and a light to my path.',
      ),
    ],
  ),
  PrayerReading(
    readings: [
      BibleReference.psalm(51),
      BibleReference.psalm(54),
      BibleReference.psalm(55),
      BibleReference.psalm(56),
      BibleReference.psalm(90),
      BibleReference.psalm(91),
    ],
    sections: [
      PrayerSection(
        title: 'Opening',
        amharic: 'በአብ፣ በወልድ፣ እና በመንፈስ ቅዱስ ስም። አሜን።',
        english: 'In the name of the Father, and of the Son, and of the Holy Spirit. Amen.',
      ),
      PrayerSection(
        title: 'Prayer',
        amharic: 'በዚህ ሰዓት እውነትን እንድንናገር አእምሮአችንን አብራ።',
        english:
            'At this hour, enlighten our minds to walk and speak in truth.',
      ),
    ],
  ),
  PrayerReading(
    readings: [
      BibleReference.psalm(51),
      BibleReference.psalm(83),
      BibleReference.psalm(84),
      BibleReference.psalm(85),
      BibleReference.psalm(86),
      BibleReference.psalm(87),
    ],
    sections: [
      PrayerSection(
        title: 'Opening',
        amharic: 'በአብ፣ በወልድ፣ እና በመንፈስ ቅዱስ ስም። አሜን።',
        english: 'In the name of the Father, and of the Son, and of the Holy Spirit. Amen.',
      ),
      PrayerSection(
        title: 'Prayer',
        amharic: 'ጌታ ሆይ፣ በምሕረትህ ጎብኘን፣ በሰላምህም ጠብቀን።',
        english: 'Lord, visit us in Your mercy and keep us in Your peace.',
      ),
    ],
  ),
  PrayerReading(
    readings: [
      BibleReference.psalm(51),
      BibleReference.psalm(116),
      BibleReference.psalm(117),
      BibleReference.psalm(118),
    ],
    sections: [
      PrayerSection(
        title: 'Opening',
        amharic: 'በአብ፣ በወልድ፣ እና በመንፈስ ቅዱስ ስም። አሜን።',
        english: 'In the name of the Father, and of the Son, and of the Holy Spirit. Amen.',
      ),
      PrayerSection(
        title: 'Hymn',
        amharic: 'ሌሊቱን በሰላም አሳልፈን፣ ለስምህ ምስጋና እንስጥ።',
        english: 'As we pass through the night in peace, let us give thanks to Your name.',
      ),
    ],
  ),
  PrayerReading(
    readings: [
      BibleReference.psalm(51),
      BibleReference.psalm(129),
      BibleReference.psalm(130),
      BibleReference.psalm(131),
      BibleReference.psalm(132),
      BibleReference.psalm(133),
    ],
    sections: [
      PrayerSection(
        title: 'Opening',
        amharic: 'በአብ፣ በወልድ፣ እና በመንፈስ ቅዱስ ስም። አሜን።',
        english: 'In the name of the Father, and of the Son, and of the Holy Spirit. Amen.',
      ),
      PrayerSection(
        title: 'Prayer',
        amharic: 'እኩለ ሌሊት ላይ እንነሳ ስምህን እንድናመሰግን አስተምረን።',
        english:
            'Teach us to rise at midnight and give thanks to Your holy name.',
      ),
    ],
  ),
];

/// Selects an hour-specific daily Scripture set from that hour's verified pool.
/// Canonical prayer sections and required Scripture remain unchanged.
List<PrayerReading> prayerReadingsForDate(DateTime date) {
  final daySeed = date.year * 10000 + date.month * 100 + date.day;
  return List<PrayerReading>.generate(prayerReadings.length, (hourIndex) {
    final canonical = prayerReadings[hourIndex];
    final pool = canonical.readings;
    if (pool.isEmpty) return canonical;
    final random = Random(daySeed + (hourIndex + 1) * 7919);
    final count = pool.length < 3 ? pool.length : 3;
    final start = random.nextInt(pool.length);
    final daily = List<BibleReference>.generate(
      count,
      (offset) => pool[(start + offset) % pool.length],
    );
    return PrayerReading(
      sections: canonical.sections,
      readings: canonical.readings,
      dailyReadings: daily,
    );
  });
}
