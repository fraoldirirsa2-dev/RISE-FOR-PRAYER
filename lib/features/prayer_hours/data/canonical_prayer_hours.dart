import 'package:rise_for_prayer/features/prayer_hours/domain/prayer_hour.dart';

/// Bundled default schedule. It is intentionally data-only, so a future
/// repository can replace times or translations without changing widgets.
const canonicalPrayerHours = <PrayerHour>[
  PrayerHour(
    prayerId: 'morning', readerIndex: 0, order: 2,
    titleAmharic: 'ጠዋት', titleEnglish: 'Morning Prayer',
    descriptionAmharic: 'የጠዋት ጸሎት', descriptionEnglish: 'Morning prayer',
    hour: 6, minute: 0, icon: '🌅',
  ),
  PrayerHour(
    prayerId: 'third', readerIndex: 1, order: 3,
    titleAmharic: 'ሦስተኛው ሰዓት', titleEnglish: 'Third Hour',
    descriptionAmharic: 'የሦስተኛው ሰዓት ጸሎት', descriptionEnglish: 'Third-hour prayer',
    hour: 9, minute: 0, icon: '☀️',
  ),
  PrayerHour(
    prayerId: 'sixth', readerIndex: 2, order: 4,
    titleAmharic: 'ስድስተኛው ሰዓት', titleEnglish: 'Sixth Hour',
    descriptionAmharic: 'የስድስተኛው ሰዓት ጸሎት', descriptionEnglish: 'Sixth-hour prayer',
    hour: 12, minute: 0, icon: '🌞',
  ),
  PrayerHour(
    prayerId: 'ninth', readerIndex: 3, order: 5,
    titleAmharic: 'ዘጠነኛው ሰዓት', titleEnglish: 'Ninth Hour',
    descriptionAmharic: 'የዘጠነኛው ሰዓት ጸሎት', descriptionEnglish: 'Ninth-hour prayer',
    hour: 15, minute: 0, icon: '🕐',
  ),
  PrayerHour(
    prayerId: 'vespers', readerIndex: 4, order: 6,
    titleAmharic: 'ሰርክ', titleEnglish: 'Vespers',
    descriptionAmharic: 'የማታ ጸሎት', descriptionEnglish: 'Evening prayer',
    hour: 18, minute: 0, icon: '🌇',
  ),
  PrayerHour(
    prayerId: 'compline', readerIndex: 5, order: 7,
    titleAmharic: 'እንቅልፍ', titleEnglish: 'Compline',
    descriptionAmharic: 'የእንቅልፍ ጸሎት', descriptionEnglish: 'Night prayer',
    hour: 21, minute: 0, icon: '🌙',
  ),
  PrayerHour(
    prayerId: 'midnight', readerIndex: 6, order: 1,
    titleAmharic: 'እኩለ ሌሊት', titleEnglish: 'Midnight Prayer',
    descriptionAmharic: 'የእኩለ ሌሊት ጸሎት', descriptionEnglish: 'Midnight prayer',
    hour: 0, minute: 0, icon: '⭐',
  ),
];
