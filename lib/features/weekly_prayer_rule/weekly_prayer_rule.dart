import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rise_for_prayer/data/prayer_content.dart';
import 'package:rise_for_prayer/features/bible/models/bible_models.dart';
import 'package:rise_for_prayer/features/bible/repositories/bible_repository.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:rise_for_prayer/features/prayer_hours/domain/prayer_schedule.dart';
import 'package:rise_for_prayer/utils/localization.dart';
import 'package:rise_for_prayer/widgets/metania_counter.dart';

enum RuleDay { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

class RuleHour {
  const RuleHour(
    this.am,
    this.en,
    this.time,
    this.readings,
    this.assignment, {
    this.special = '',
    this.psalmChapters = const [],
    this.midnightPsalmChapters = const [],
  });
  final String am, en, time, assignment, special;
  final List<String> readings;
  final List<int> psalmChapters;
  final List<int> midnightPsalmChapters;
}

/// Reusable reading content for the selected weekday and prayer hour.
/// Embeds the same schedule content used by the full prayer-rule session.
class WeeklyPrayerRuleReading extends StatelessWidget {
  const WeeklyPrayerRuleReading({
    super.key,
    required this.day,
    required this.hour,
    this.language = 'en',
    this.metaniaEnabled = true,
  });
  final int day;
  final int hour;
  final String language;
  final bool metaniaEnabled;

  @override
  Widget build(BuildContext context) {
    final item = weeklyPrayerRule[day][hour];
    final psalmChapters = [
      ...item.psalmChapters,
      ...item.midnightPsalmChapters,
    ];
    final colors = Theme.of(context).colorScheme;
    const textSize = 19.0;
    final amharicStyle = TextStyle(
      fontFamily: 'AbyssinicaSIL',
      color: colors.onSurface,
      fontSize: textSize,
      height: 1.9,
    );
    final prayerTextStyle = language == 'eth'
        ? amharicStyle
        : GoogleFonts.ebGaramond(
            fontSize: textSize,
            height: 1.7,
            color: colors.onSurface,
          );
    Widget block(String title, List<Widget> children) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: TextAlign.start,
            style: GoogleFonts.cinzel(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        block(localizedText(language, 'መክፈቻ ጸሎት', 'Opening Prayer'), [
          _prayerQuote(
            localizedText(language, 'አቡነ ዘበሰማያት', 'Abune Zebesemayat'),
            _openingPrayerText(language),
            prayerTextStyle,
            colors,
          ),
          if (day == 6 && item.assignment.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(
              _assignmentLabel(item, day, hour, language),
              textAlign: TextAlign.start,
              style: prayerTextStyle,
            ),
          ],
          if (item.special.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(
              language == 'eth'
                  ? item.special
                  : 'Hymn of Praise to Mary for ${_daysEn[day]}',
              textAlign: TextAlign.start,
              style: prayerTextStyle,
            ),
          ],
        ]),
        if (psalmChapters.isNotEmpty)
          block(localizedText(language, 'መዝሙረ ዳዊት', 'Psalm'), [
            for (final chapter in psalmChapters)
              _PsalmChapterCard(
                chapter: chapter,
                language: language,
                textSize: textSize,
              ),
          ]),
        block(localizedText(language, 'የመጽሐፍ ቅዱስ ንባቦች', 'Bible Reading'), [
          for (final reference in item.readings)
            _BibleReadingCard(
              referenceText: _referenceLabel(
                _referenceFor(reference),
                reference,
                language,
              ),
              reference: _referenceFor(reference),
              language: language,
              textSize: textSize,
            ),
        ]),
        MetaniaCounter(prayerHourId: hour, enabled: metaniaEnabled),
        block(localizedText(language, 'መዝጊያ ጸሎት', 'Closing prayer'), [
          _prayerQuote(
            localizedText(language, 'አቡነ ዘበሰማያት', 'Abune Zebesemayat'),
            language == 'eth' ? _closingOurFather : _closingOurFatherEnglish,
            prayerTextStyle,
            colors,
          ),
          const SizedBox(height: 12),
          _prayerQuote(
            localizedText(language, 'የማርያም ጸሎት', 'Marian prayer'),
            language == 'eth'
                ? _closingMarianPrayer
                : _closingMarianPrayerEnglish,
            prayerTextStyle,
            colors,
          ),
        ]),
      ],
    );
  }

  Widget _prayerQuote(
    String title,
    String text,
    TextStyle style,
    ColorScheme colors,
  ) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    decoration: BoxDecoration(
      color: colors.primary.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(12),
      border: Border(
        left: BorderSide(
          color: colors.primary.withValues(alpha: 0.65),
          width: 3,
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(text, textAlign: TextAlign.start, style: style),
      ],
    ),
  );
}

const _days = ['ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ', 'እሑድ'];
const _hours = [
  ('ቀዳሚት', 'Prime', '12:00 ሰዓት'),
  ('ሦስተኛ', 'Terce', '3:00 ሰዓት'),
  ('ስድስተኛ', 'Sext', '6:00 ሰዓት'),
  ('ዘጠነኛ', 'Nones', '9:00 ሰዓት'),
  ('ምሽት', 'Vespers', '11:00 ሰዓት'),
  ('ሌሊት', 'Compline', 'የመኝታ ጊዜ'),
  ('መንፈቀ ሌሊት', 'Midnight', 'እኩለ ሌሊት'),
];
const _daysEn = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _hourTimesEn = [
  '6:00 AM',
  '9:00 AM',
  '12:00 PM',
  '3:00 PM',
  '6:00 PM',
  '9:00 PM',
  '12:00 AM',
];
const _readings = [
  ['ማቴዎስ 27፥1-2', 'መዝሙር 5፥3'],
  ['ዮሐንስ 19፥1', 'ሐዋርያት ሥራ 2፥15', 'ሉቃስ 1፥28', 'ዳንኤል 6፥10'],
  ['ዮሐንስ 19፥23-29'],
  ['ማርቆስ 15፥34-38', 'ማቴዎስ 27፥50', 'ሐዋርያት ሥራ 10፥1-4'],
  ['ማቴዎስ 27፥58-60'],
  ['ሉቃስ 11፥1-4', 'ማቴዎስ 26፥47-51'],
  ['ማቴዎስ 25፥6', 'ሐዋርያት ሥራ 16፥25'],
];
const _ranges = [
  ['1 – 5', '6 – 10', '11 – 15', '16 – 20', '21 – 25', '26 – 30'],
  ['31 – 35', '36 – 40', '41 – 45', '46 – 50', '51 – 55', '56 – 60'],
  ['61 – 63', '64 – 66', '67 – 69', '70 – 72', '73 – 76', '77 – 80'],
  ['81 – 85', '86 – 90', '91 – 95', '96 – 100', '101 – 105', '106 – 110'],
  [
    '111 – 113',
    '114 – 116',
    '117 – 119 (ክፍል 1)',
    '119 (ክፍል 2) – 122',
    '123 – 126',
    '127 – 130',
  ],
  [
    '131 – 133',
    '134 – 136',
    '137 – 139',
    '140 – 142',
    '143 – 146',
    '147 – 150',
  ],
];
// Divide Psalms 1–30 across the seven midnight services, in weekday order.
const _midnightPsalmRanges = [
  (1, 5),
  (6, 10),
  (11, 14),
  (15, 18),
  (19, 22),
  (23, 26),
  (27, 30),
];
const _special = ['ዘሰኞ', 'ዘማክሰኞ', 'ዘረቡዕ', 'ዘሐሙስ', 'ዘዓርብ', 'ዘቅዳሜ', 'ዘእሑድ'];
final weeklyPrayerRule = List<List<RuleHour>>.generate(
  7,
  (d) => List.generate(7, (h) {
    final assignment = d == 6
        ? const [
            'ጸሎተ ነቢያት ክፍል 1 – 2 (ጸሎተ ሙሴ 1 እና 2)',
            'ጸሎተ ነቢያት ክፍል 3 – 5 (ጸሎተ ሙሴ 3፣ ሐና፣ ሕዝቅያስ)',
            'ጸሎተ ነቢያት ክፍል 6 – 8 (ጸሎተ ምናሴ፣ ዮናስ፣ ዳንኤል)',
            'ጸሎተ ነቢያት ክፍል 9 – 11 (ጸሎተ ሠለስቱ ደቂቅ፣ ዕንባቆም፣ ኢሳይያስ)',
            'ጸሎተ ነቢያት ክፍል 12 – 13 (ጸሎተ ማርያም፣ ዘካርያስ)',
            'ጸሎተ ነቢያት ክፍል 14 – 15 (ጸሎተ ስምዖን፣ ዕዝራ)',
            'ውዳሴ ማርያም ዘእሑድ እና ቅዳሴ ማርያም',
          ][h]
        : h == 6
        ? ''
        : 'መዝሙር ${_ranges[d][h]}';
    final dailyPsalms = _dailyPsalmsForHour(d, h);
    final psalmChapters = dailyPsalms.isNotEmpty
        ? dailyPsalms
        : d == 6
        ? prayerReadings[h].readings
              .map((reference) => reference.chapter)
              .toList(growable: false)
        : dailyPsalms;
    final assignmentText = d < 6
        ? _psalmRangeLabel(dailyPsalms)
        : assignment.toString();
    final midnightPsalmChapters = h == 6
        ? List<int>.generate(
            _midnightPsalmRanges[d].$2 - _midnightPsalmRanges[d].$1 + 1,
            (index) => _midnightPsalmRanges[d].$1 + index,
          )
        : const <int>[];
    return RuleHour(
      _hours[h].$1,
      _hours[h].$2,
      _hours[h].$3,
      List.unmodifiable(_readings[h]),
      assignmentText,
      special: h == 6 && d < 6 ? 'ውዳሴ ማርያም ${_special[d]}' : '',
      psalmChapters: List.unmodifiable(psalmChapters),
      midnightPsalmChapters: List.unmodifiable(midnightPsalmChapters),
    );
  }),
);

List<int> _chaptersFromRange(String range) {
  final visibleRange = range.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
  final numbers = RegExp(r'\d+')
      .allMatches(visibleRange)
      .map((match) => int.parse(match.group(0)!))
      .toList(growable: false);
  if (numbers.isEmpty) return const [];
  final first = numbers.first;
  final last = numbers.length > 1 ? numbers.last : first;
  return List<int>.generate(last - first + 1, (index) => first + index);
}

List<int> _dailyPsalmsForHour(int day, int hour) {
  if (day < 0 || day >= 6 || hour < 0 || hour >= 7) return const [];
  final chapters = _ranges[day].expand(_chaptersFromRange).toSet().toList()
    ..sort();
  final start = chapters.length * hour ~/ 7;
  final end = chapters.length * (hour + 1) ~/ 7;
  return List.unmodifiable(chapters.sublist(start, end));
}

String _psalmRangeLabel(List<int> chapters) {
  if (chapters.isEmpty) return '';
  final range = chapters.length == 1
      ? '${chapters.first}'
      : '${chapters.first}\u2013${chapters.last}';
  return '\u1218\u12DD\u1239\u122D $range';
}

String _assignmentLabel(RuleHour item, int day, int hour, String language) {
  if (language == 'eth') return item.assignment;
  if (day == 6 && hour < 6) {
    const parts = [
      'Prayer of Moses',
      'Prayers of Moses, Hannah, and Hezekiah',
      'Prayers of Manasseh, Jonah, and Daniel',
      'Prayers of the Three Youths, Habakkuk, and Isaiah',
      'Prayers of Mary and Zechariah',
      'Prayers of Simeon and Ezra',
    ];
    return parts[hour];
  }
  if (day == 6 && hour == 6) {
    return 'Wudase Maryam and Kidase Maryam';
  }
  if (item.psalmChapters.isNotEmpty) {
    final chapters = item.psalmChapters;
    return chapters.length == 1
        ? 'Psalm ${chapters.first}'
        : 'Psalms ${chapters.first}–${chapters.last}';
  }
  if (item.special.isNotEmpty) return 'Hymn of Praise to Mary';
  return '';
}

const String _commonEnglish = '''
I cross my face and all of myself by the sign of the cross. In the name of father, and son and the Holy Spirit one God AMEN. In the Holy Trinity believing and entrusting myself, I deny you satan in front of my mother the Holy Church, who is my witness, St. Mary Tsion forever. AMEN

We thank you Oh Lord, and we glorify you, we praise. you Oh Lord, and we rely on you, we beg you and we beseech you. We worship you and we serve to your Holy name. We bow and kneel down to you; oh, you to whom all knees should bow and who all tongues serve. You are the God of gods and the Lord of lords and the king of kings. You are God to all flesh and to. all souls, and we call you as your Holy Son taught us saying “But when you pray you shall say”, Our Father who are in heaven …

Our father who art in heaven, hollowed be they name, thy Kingdom come, thy will be done in earth as it is in heaven: give us this day our daily bread and forgive us our trespasses as we forgive them that trespass against us, and lead us not into temptation but deliver us and rescue us from all evil for thine is the kingdom, the power and the. Glory for even and ever. AMEN

By the Salutation of the Saint Angel Gabriel, O my Lady Mary I salute you, thou are Virgin in thought, and Virgin in body the Mother of God Tsabaot. (The Lord of Hosts) salutation to you. Blessed art thou, among women and blessed is the fruit of your womb. Rejoice thou who is hailed, O Graceful God is with you. Beseech and pray for our mercy to you beloved Son JESUS CHRIST that he may forgive us our sins. AMEN

We believe in one God, the father Almighty, maker of heaven and earth, and all things visible and invisible and we believe in One Lord Jesus Christ the only begotten son of the Father who was with him before the creation of the World.

Light from light, true God from true God, begotten not made of one essense with the Father. By whom all things were made, and without him was not anything in heaven or earth made.

Who for us men and for our salvation came down from heaven was made man and was incarnate from the Holy Spirit and from the Holy Virgin Mary. Become man was crucified for our sakes in the days of Pontius Pilate suffered, died, was buried and rose from the dead on the third day as was written in the Holy Scriptures: Ascended in glory into heaven, sat at the right hand of his Father, and will come again in glory to judge the Living and the dead; there is no end to his reign.

And we believe in the Holy Spirit, the life-giving God, who proceeded from the Father; we worship and glorify him with the Father, and the Son; who spoke by the prophets.

And we believe in one baptism from the remission of sins, and walt for the resurrection from the dead and the life to come, world without end, AMEN.

Holy, Holy, Holy God Tsabaot perfect Lord of Host, heaven and earth are full of the holiness of your Glory. We bow to you Christ, with your good heavenly Father and with your Holy Spirits the life Giver from thou didst come and save us.

Let us bow down to the father, and the Son, and the Holy Spirit: Three in one and one in three. Three in person and united in Godhead. I bow down to our Lady St. Mary Virgin Mother God. I bow down to the cross of our Lord Jesus Christ which was sanctified by his precious Blood. The cross is our power, the Cross is our strength, the Cross is our redemption, the cross is the salvation of our soul. The Jews denied but we believe, and those who believe in the power of the Cross are saved.

Glory To The Father, Glory To The Son, Glory To The Holy Spirit (Three Times). Glory to our Lady St. Mary the Virgin Mother of God. Glory to the Cross of our Lord Jesus Christ. May Christ in his mercy remember us. May he not put us to shame in his second coming. May he awaken us to the glorification of his name. In his worship may he maintain us. Our Lady St. Mary, lift up our prayer before the throne of our Lord, who gave us to eat this bread, and who gave us to drink this cup, and who prepared our food and our clothing for us, and who overlooked all our sins, and who gave us his Holy Body and his precious Blood, who brought us to this hour.

Let us give glory and thanks of God the Most High and to his Virgin Mother and to his precious Cross. May the name of the Lord be thanked and glorified always at all times and at every hour.
''';
const String _marianPrayerEnglish = '''
By the Salutation of the Saint Angel Gabriel, O my Lady Mary I salute you, thou are Virgin in thought, and Virgin in body the Mother of God Tsabaot. (The Lord of Hosts) salutation to you. Blessed art thou, among women and blessed is the fruit of your womb. Rejoice thou who is hailed, O Graceful God is with you. Beseech and pray for our mercy to you beloved Son JESUS CHRIST that he may forgive us our sins. AMEN
''';

const String _common = '''
በጌታዬ በኢየሱስ ክርስቶስ ትዕምርተ መስቀል ፊቴንና መላ ሰውነቴን ሦስት ጊዜ አማትባለሁ፡፡ አንድ አምላክ በሆኑ በአብ በወልድ በመንፈስ ቅዱስ ስም ንጹሕ ልዩ ክቡር ጽሩይ በሆኑ በሦስትነት ወይም በሥላሴ እያመንኩና እየተማጸንኩ ጠላቴ ሰይጣንን እክድሃለሁ፤ በዚህች በእናቴ በቤተ ክርስቲያን ፊት ቁሜ እክድሃለሁ ለዚህም ምስክሬ ማርያም ናት። በዚህም ዓለም በወዲያኛውም ዓለም እሷን አምባ መጠጊያ አድርጌ እክድሃለሁ።

አቤቱ እናመሰግንሃለን አቤቱ እናከብርሃለን አቤቱ እንገዛልሃለን አቤቱ ቅዱስ ስምህን እናመሰግንሃለን። ጉልበት ሁሉ የሚሰግድልህ አቤቱ እንሰግድልሃለን አንደበትም ሁሉ ለአንተ ይገዛል የአምላኮች አምላክ፣ የጌቶች ጌታ፣የንጉሦችም ንጉሥ አንተ ነህ የሥጋም የነፍስም ፈጣሪ አንተ ነህ። እናንተስ በምትጸልዩበት ጊዜ እንዲህ ብላችሁ ጸልዩ ብሎ ቅዱስ ልጅህ እንዳስተማረን እንጠራሃለን።

አባታችን ሆይ በሰማያት የምትኖር ስምህ ይቀደስ መንግሥትህ ትምጣ ፈቃድህ በሰማይ እንደሆነች እንዲሁም በምድር ትሁን የዕለት እንጀራችንን ስጠን ዛሬ፤በደላችንንም ይቅር በለን እኛም የበደሉንን ይቅር እንደምንል። አቤቱ ወደ ፈተናም አታግባን ከክፉ ሁሉ አድነን እንጂ መንግሥት የአንተ ናትና ኃይል ክብር ምስጋና ለዘለዓለሙ አሜን።

እመቤታችን ቅድስት ድንግል ማርያም ሆይ በመልአኩ በቅዱስ ገብርኤል ሰላምታ ሰላም እልሻለሁ። በሀሳብሽ ድንግል ነሽ በሥጋሽም ድንግል ነሽ። የአቸናፊ የእግዚአብሔር እናት ሆይ ለአንቺ ሰላምታ ይገባል ከሴቶቹ ሁሉ ተለይተሽ አንቺ የተባረክሽ ነሽና የማኅፀንሽም ፍሬ የተባረከ ነው። ጸጋን የተመላሽ ሆይ ደስ ይበልሽ እግዚአብሔር ከአንቺ ጋር ነውና ከተወደደው ልጅሽ ከጌታችን ከመድኃኒታችን ከኢየሱስ ክርስቶስ ዘንድ ይቅርታንና ምሕረትን ለምኝልን ኃጢአታችንንም ያስተሠርይልን ዘንድ ለዘለዓለሙ አሜን።

ሁሉን የፈጠረ አንድ አምላክ በሚሆን በእግዚአብሔር አብ እናምናለን። ሰማይንና ምድርን የፈጠረ የሚታየውንና የማይታየውን። ዓለም ሳይፈጠር ከእርሱ ጋር በነበረ አንድ የአብ ልጅ በሚሆን በአንድ ጌታ በኢየሱስ ክርስቶስ እናምናለን ከብርሃን የተገኘ ብርሃን ከእውነተኛ አምላክ የተገኘ አምላክ። የተወለደ እንጂ ያልተፈጠረ በባሕርዩ ከአብ ጋር የሚተካከል ሁሉ በእርሱ የሆነ በሰማይም ካለው በምድርም ካለው ያለ እርሱ ምንም ምን የሆነ የለም።

ስለእኛ ስለ ሰዎች እኛን ለማዳን ከሰማይ ወረደ፤ በመንፈስ ቅዱስ ግብር ከቅድስት ድንግል ማርያም ፍጹም ሰው ሆነ ደግሞም ስለእኛ ተሰቀለ በጰንጤናዊ በጲላጦስ ዘመን እርሱ መከራን ተቀበለ፣ሞተ፣ተቀበረ፤በሦስተኛውም ቀን ከሙታን ተለይቶ ተነሳ፤ በቅዱሳት መጻሕፍት እንደተጻፈ በክብር በምስጋና ወደ ሰማይ ዐረገ በአባቱም ቀኝ ተቀመጠ፤ዳግመኛም በሕያዋንና በሙታን ላይ ለመፍረድ በምስጋና ይመጣል፤ለመንግሥቱም ፍጻሜ የለውም።

በመንፈስ ቅዱስም እናምናለን እርሱም ጌታ ሕይወትን የሚሰጥ ከአብ የሠረፀ ከአብና ከወልድ ጋራ በአንድነት እንሰግድለታለን እናመሰግነዋለን እርሱም በነቢያት አድሮ የተናገረ ነው፤ከሁሉም በላይ በምትሆን ሐዋርያት በሠሯት በአንዲት ቅድስት ቤተ ክርስቲያን እናምናለን፤ ኃጢአት በሚሠረይባት በአንዲት ጥምቀትም እናምናለን፤ የሙታንንም መነሣት ተስፋ እናደርጋለን፤የሚመጣውንም ሕይወት ለዘለዓለሙ አሜን።

አቸናፊ እግዚአብሔር ሆይ ቅዱስ ቅዱስ ቅዱስ ተብለህ ትመሰገናለህ። ምስጋናህም በሰማይና በምድር የመላ ነው። ክርስቶስ ለአንተ እንሰግድልሃለን ከሰማያዊ ከቸር አባትህ ጋራ አዳኝ ከሆነ ከመንፈስ ቅዱስም ጋራ እንሰግድልሃለን ወደዚህ ዓለም መጥተህ አድነኸናልና።

ለአብ ለወልድ ለመንፈስ ቅዱስ አንዲት ስግደት እሰግዳለሁ (3 ጊዜ) አንድ ሲሆን ሦስት፤ሦስት ሲሆኑ አንድ፤ በአካል ሦስት ሲሆኑ በመለኮት አንድ ለሚሆኑ እሰግዳለሁ። አምላክን ለወለደች ለእመቤታችን ለድንግል ማርያም እሰግዳለሁ፤ዓለምን ሁሉ ለማዳን ሲል ኢየሱስ ክርስቶስ ለተሰቀለበት መስቀልም እሰግዳለሁ። መስቀል ኃይላችን ነው፤ ኃይላችን መስቀል ነው፤ የሚያጸናን መስቀል ነው፤ መስቀል ቤዛችን ነው፤መስቀል የነፍሳችን መዳኛ ነው። አይሁድ ይክዱታል እኛ ግን እናምነዋል ያመነው እኛም በመስቀሉ እንድናለን ድነናልም።

ለአብ ምስጋና ይገባል ለወልድም ምስጋና ይገባል ለመንፈስ ቅዱስም ምስጋና ይገባል (3 ጊዜ) አምላክን ለወለደች ለእመቤታችን ለድንግል ማርያም ምስጋና ይገባል፤ለኢየሱስ ክርስቶስ መስቀልም ምስጋና ይገባል። ክርስቶስ በቸርነቱ ያስበን ዘንድ ዳግመኛም በመጣ ጊዜ እንዳያሳፍረን ስሙን ለማመስገን ያነቃን ዘንድ።

እርሱንም በማምለክ ያፀናን ዘንድ። እመቤታችን ጸሎታችንን አሳርጊልን ኃጢአታችንንም አስተሥርዪልን በጌታችን መንበር ፊት ጸሎታችንን አሳርጊልን ይህንን ኅብስት ላበላን ይህንንም ጽዋ ላጠጣን ምግባችንንና ልብሳችንንም ላዘጋጀልን ፤ ኃጢአታችንንም ሁሉ ለታገሰልን ፤ ክቡር ደሙን ቅዱስ ሥጋውን ለሰጠን ፤ እስከዚህችም ሰዓት ላደረሰን፤ ለእርሱ ለልዑል እግዚአብሔር ፍጹም ምስጋና ይገባል ለወለደችው ለድንግልም ምስጋና ይገባል። ለክቡር መስቀሉም ምስጋና ይገባል። የእግዚአብሔር ስሙ ፈጽሞ ይመሰገን ዘንድ ዘወትር በየጊዜያቱና በየሰዓቱ ምስጋና ይገባል።
''';

const String _marianPrayer = '''
እመቤታችን ቅድስት ድንግል ማርያም ሆይ በመልአኩ በቅዱስ ገብርኤል ሰላምታ ሰላም እልሻለሁ። በሀሳብሽ ድንግል ነሽ በሥጋሽም ድንግል ነሽ። የአቸናፊ የእግዚአብሔር እናት ሆይ ለአንቺ ሰላምታ ይገባል ከሴቶቹ ሁሉ ተለይተሽ አንቺ የተባረክሽ ነሽና የማኅፀንሽም ፍሬ የተባረከ ነው። ጸጋን የተመላሽ ሆይ ደስ ይበልሽ እግዚአብሔር ከአንቺ ጋር ነውና ከተወደደው ልጅሽ ከጌታችን ከመድኃኒታችን ከኢየሱስ ክርስቶስ ዘንድ ይቅርታንና ምሕረትን ለምኝልን ኃጢአታችንንም ያስተሠርይልን ዘንድ ለዘለዓለሙ አሜን።
''';

const String _closingOurFather = '''
አባታችን ሆይ በሰማያት የምትኖር ስምህ ይቀደስ መንግሥትህ ትምጣ ፈቃድህ በሰማይ እንደሆነች እንዲሁም በምድር ትሁን የዕለት እንጀራችንን ስጠን ዛሬ፤በደላችንንም ይቅር በለን እኛም የበደሉንን ይቅር እንደምንል። አቤቱ ወደ ፈተናም አታግባን ከክፉ ሁሉ አድነን እንጂ መንግሥት የአንተ ናትና ኃይል ክብር ምስጋና ለዘለዓለሙ አሜን።
''';

const String _closingMarianPrayer = '''
እመቤታችን ቅድስት ድንግል ማርያም ሆይ በመልአኩ በቅዱስ ገብርኤል ሰላምታ ሰላም እልሻለሁ። በሀሳብሽ ድንግል ነሽ በሥጋሽም ድንግል ነሽ። የአቸናፊ የእግዚአብሔር እናት ሆይ ለአንቺ ሰላምታ ይገባል ከሴቶቹ ሁሉ ተለይተሽ አንቺ የተባረክሽ ነሽና የማኅፀንሽም ፍሬ የተባረከ ነው። ጸጋን የተመላሽ ሆይ ደስ ይበልሽ እግዚአብሔር ከአንቺ ጋር ነውና ከተወደደው ልጅሽ ከጌታችን ከመድኃኒታችን ከኢየሱስ ክርስቶስ ዘንድ ይቅርታንና ምሕረትን ለምኝልን ኃጢአታችንንም ያስተሠርይልን ዘንድ ለዘለዓለሙ አሜን።
''';

String _openingPrayerText(String language) {
  final isAmharic = language == 'eth';
  final commonPrayer = isAmharic ? _common : _commonEnglish;
  final marianPrayer = isAmharic ? _marianPrayer : _marianPrayerEnglish;
  return commonPrayer.replaceFirst(marianPrayer, '').trim();
}

const String _closingOurFatherEnglish = '''
Our father who art in heaven, hollowed be they name, thy Kingdom come, thy will be done in earth as it is in heaven: give us this day our daily bread and forgive us our trespasses as we forgive them that trespass against us, and lead us not into temptation but deliver us and rescue us from all evil for thine is the kingdom, the power and the. Glory for even and ever. AMEN
''';

const String _closingMarianPrayerEnglish = '''
By the Salutation of the Saint Angel Gabriel, O my Lady Mary I salute you, thou are Virgin in thought, and Virgin in body the Mother of God Tsabaot. (The Lord of Hosts) salutation to you. Blessed art thou, among women and blessed is the fruit of your womb. Rejoice thou who is hailed, O Graceful God is with you. Beseech and pray for our mercy to you beloved Son JESUS CHRIST that he may forgive us our sins. AMEN
''';

String _referenceLabel(
  BibleReference? reference,
  String original,
  String language,
) {
  if (language == 'eth' || reference == null) return original;
  const books = {
    'book_40': 'Matthew',
    'psalms': 'Psalm',
    'book_43': 'John',
    'book_44': 'Acts',
    'book_42': 'Luke',
    'book_27': 'Daniel',
    'book_41': 'Mark',
  };
  final book = books[reference.bookId];
  if (book == null) return original;
  final verses = reference.startVerse == reference.endVerse
      ? '${reference.startVerse}'
      : '${reference.startVerse}-${reference.endVerse}';
  return '$book ${reference.chapter}:$verses';
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class WeeklyPrayerRuleScreen extends ConsumerStatefulWidget {
  const WeeklyPrayerRuleScreen({super.key});
  @override
  ConsumerState<WeeklyPrayerRuleScreen> createState() =>
      _WeeklyPrayerRuleScreenState();
}

class _WeeklyPrayerRuleScreenState
    extends ConsumerState<WeeklyPrayerRuleScreen> {
  final _search = TextEditingController();
  Future<int> _done(int d) async {
    final p = await SharedPreferences.getInstance();
    return List.generate(
      7,
      (h) => p.getBool('weekly_${_dateKey(DateTime.now())}_${d}_$h') ?? false,
    ).where((v) => v).length;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(settingsProvider).language;
    String dayName(int index) =>
        localizedText(language, _days[index], _daysEn[index]);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizedText(language, 'የሳምንቱ የጸሎት ሥርዓት', 'Weekly prayer rule'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                localizedText(
                  language,
                  'መዝሙረ ዳዊት እና የጸሎት ሥርዓት',
                  'Psalms and the daily prayer order',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: localizedText(
                    language,
                    'መዝሙር፣ መጽሐፍ፣ ቀን ወይም ጸሎት ፈልግ',
                    'Search psalms, readings, days, or prayers',
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RuleDayScreen(day: DateTime.now().weekday - 1),
                  ),
                ),
                child: Text(
                  localizedText(language, 'የዛሬ ጸሎት', "Today's prayer"),
                ),
              ),
              for (var d = 0; d < 7; d++)
                if (_search.text.isEmpty ||
                    dayName(d)
                        .toLowerCase()
                        .contains(_search.text.toLowerCase()) ||
                    weeklyPrayerRule[d].any(
                      (item) =>
                          item.am.contains(_search.text) ||
                          item.en.toLowerCase().contains(
                            _search.text.toLowerCase(),
                          ) ||
                          item.assignment.contains(_search.text) ||
                          item.special.contains(_search.text) ||
                          item.readings.any((r) => r.contains(_search.text)),
                    ))
                  Card(
                    color: d == DateTime.now().weekday - 1
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: ListTile(
                      isThreeLine: true,
                      title: Text(
                        dayName(d),
                        style: const TextStyle(fontSize: 21),
                      ),
                      subtitle: Text(
                        d == 6
                            ? localizedText(
                                language,
                                'ጸሎተ ነቢያት · 15ቱ ክፍሎች',
                                'Prayer of the Prophets · 15 parts',
                              )
                            : localizedText(
                                language,
                                'መዝሙር ${_ranges[d].first} – ${_ranges[d].last}',
                                'Psalms ${_ranges[d].first} – ${_ranges[d].last}',
                              ),
                      ),
                      trailing: FutureBuilder<int>(
                        future: _done(d),
                        builder: (c, s) => Text(
                          '${s.data ?? 0}/7 ${localizedText(language, 'ተጠናቋል', 'done')}',
                        ),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RuleDayScreen(day: d),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class RuleDayScreen extends ConsumerWidget {
  const RuleDayScreen({super.key, required this.day});
  final int day;
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final language = ref.watch(settingsProvider).language;
    final dayName = localizedText(language, _days[day], _daysEn[day]);
    return Scaffold(
      appBar: AppBar(title: Text(dayName)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dayName, style: Theme.of(c).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        localizedText(
                          language,
                          '7 የጸሎት ሰዓታት · ${day == 6 ? '15 የነቢያት ጸሎት ክፍሎች' : 'መዝሙር ${_ranges[day].first} – ${_ranges[day].last}'}',
                          '7 prayer hours · ${day == 6 ? '15-part Prayer of the Prophets' : 'Psalms ${_ranges[day].first} – ${_ranges[day].last}'}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<int>(
                        future: _completedForToday(day),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizedText(
                                  language,
                                  'ዛሬ የተጠናቀቀው: $count / 7',
                                  'Completed today: $count / 7',
                                ),
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(value: count / 7),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (var h = 0; h < 7; h++)
                _RuleHourTile(day: day, hour: h, language: language),
            ],
          ),
        ),
      ),
    );
  }
}

Future<int> _completedForToday(int day) async {
  final prefs = await SharedPreferences.getInstance();
  var count = 0;
  for (var hour = 0; hour < 7; hour++) {
    if (prefs.getBool('weekly_${_dateKey(DateTime.now())}_${day}_$hour') ??
        false) {
      count++;
    }
  }
  return count;
}

class _RuleHourTile extends StatelessWidget {
  const _RuleHourTile({
    required this.day,
    required this.hour,
    required this.language,
  });
  final int day, hour;
  final String language;
  @override
  Widget build(BuildContext context) {
    final item = weeklyPrayerRule[day][hour];
    final colors = Theme.of(context).colorScheme;
    final isEnglish = language == 'en';
    final assignment = _assignmentLabel(item, day, hour, language);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RuleSessionScreen(day: day, hour: hour),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  '${hour + 1}'.padLeft(2, '0'),
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedText(language, item.am, item.en),
                      style: Theme.of(context).textTheme.titleMedium,
                      softWrap: true,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${localizedText(language, item.time, _hourTimesEn[hour])} ${localizedText(language, 'ሰዓት', 'hour')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (assignment.isNotEmpty ||
                        item.midnightPsalmChapters.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        [
                          if (assignment.isNotEmpty) assignment,
                          if (item.midnightPsalmChapters.isNotEmpty)
                            localizedText(
                              language,
                              'የእኩለ ሌሊት መዝሙር ${item.midnightPsalmChapters.first}–${item.midnightPsalmChapters.last}',
                              'Midnight Psalms ${item.midnightPsalmChapters.first}–${item.midnightPsalmChapters.last}',
                            ),
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodyMedium,
                        softWrap: true,
                      ),
                    ],
                    if (item.special.isNotEmpty && !isEnglish) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.special,
                        style: Theme.of(context).textTheme.bodyMedium,
                        softWrap: true,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      localizedText(
                        language,
                        '${item.readings.length} ንባቦች',
                        '${item.readings.length} readings',
                      ),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class RuleSessionScreen extends ConsumerStatefulWidget {
  const RuleSessionScreen({super.key, required this.day, required this.hour});
  final int day, hour;
  @override
  ConsumerState<RuleSessionScreen> createState() => _RuleSessionScreenState();
}

class _RuleSessionScreenState extends ConsumerState<RuleSessionScreen> {
  bool done = false;
  bool _showCelebration = false;
  bool _leavingAfterCompletion = false;
  bool _isUpcomingHour = false;
  Timer? _unlockTimer;
  @override
  void initState() {
    super.initState();
    _updateCompletionLock(notify: false);
    _load();
  }

  void _updateCompletionLock({bool notify = true}) {
    final timeService = ref.read(timeServiceProvider);
    final now = timeService.now;
    var isUpcoming = false;
    if (widget.day == now.weekday - 1) {
      final occurrence = timeService
          .prayerOccurrencesFor(now)
          .firstWhere((item) => item.prayerHour.readerIndex == widget.hour);
      isUpcoming =
          timeService.prayerStatus(occurrence, now) == PrayerStatus.upcoming;
      _unlockTimer?.cancel();
      if (isUpcoming) {
        final wait = occurrence.at.difference(now);
        _unlockTimer = Timer(wait + const Duration(milliseconds: 100), () {
          if (mounted) _updateCompletionLock();
        });
      }
    } else {
      _unlockTimer?.cancel();
    }
    if (_isUpcomingHour == isUpcoming) return;
    if (notify) {
      setState(() => _isUpcomingHour = isUpcoming);
    } else {
      _isUpcomingHour = isUpcoming;
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => done = prefs.getBool(_key) ?? false);
  }

  String get _key =>
      'weekly_${_dateKey(DateTime.now())}_${widget.day}_${widget.hour}';
  Future<void> _toggle() async {
    if (_leavingAfterCompletion || _isUpcomingHour) return;
    final nextValue = !done;
    setState(() {
      done = nextValue;
      _showCelebration = nextValue;
      _leavingAfterCompletion = nextValue;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, nextValue);
    } catch (_) {
      if (mounted) {
        setState(() {
          done = !nextValue;
          _showCelebration = false;
          _leavingAfterCompletion = false;
        });
      }
      return;
    }
    // Prayer completion is recorded only from this explicit button action.
    // Metania taps and its auto-count timer never complete the prayer.
    ref.read(prayerProvider).setHourCompleted(widget.hour, nextValue);
    if (!nextValue) return;
    await Future<void>.delayed(const Duration(milliseconds: 1250));
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = weeklyPrayerRule[widget.day][widget.hour];
    final language = ref.watch(settingsProvider).language;
    const textSize = 19.0;
    final isEnglish = language == 'en';
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    TextStyle ethiopic({
      double size = 19,
      FontWeight weight = FontWeight.normal,
    }) => TextStyle(
      fontFamily: 'AbyssinicaSIL',
      fontSize: size,
      fontWeight: weight,
      height: 1.85,
      color: colors.onSurface,
    );
    Widget section(String title, Widget child) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: isEnglish
                ? GoogleFonts.cinzel(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  )
                : ethiopic(size: 22, weight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizedText(language, item.am, item.en),
          style: isEnglish
              ? GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w600)
              : ethiopic(size: 22, weight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${localizedText(language, _days[widget.day], _daysEn[widget.day])}  |  ${widget.hour + 1} / 7',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizedText(language, item.am, item.en),
                          textAlign: TextAlign.start,
                          style: isEnglish
                              ? GoogleFonts.cinzel(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onPrimaryContainer,
                                )
                              : ethiopic(
                                  size: 28,
                                  weight: FontWeight.w600,
                                ).copyWith(color: colors.onPrimaryContainer),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${localizedText(language, item.time, _hourTimesEn[widget.hour])}  |  ${localizedText(language, 'ሰዓት', 'Prayer hour')}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isUpcomingHour)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer.withValues(
                          alpha: 0.65,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        localizedText(
                          language,
                          'ይህ የጸሎት ሰዓት ገና አልደረሰም። ማንበብ ይችላሉ፤ ጸሎቱን ማጠናቀቅ የሚቻለው ሰዓቱ ሲደርስ ነው።',
                          'This prayer hour has not started yet. You can read it now, and mark it complete when its time arrives.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  section(
                    localizedText(language, 'መክፈቻ ጸሎት', 'Opening Prayer'),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _openingPrayerText(language),
                          style: isEnglish
                              ? GoogleFonts.ebGaramond(
                                  fontSize: textSize,
                                  height: 1.7,
                                )
                              : ethiopic(size: textSize),
                        ),
                        if (widget.day == 6 && item.assignment.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            _assignmentLabel(
                              item,
                              widget.day,
                              widget.hour,
                              language,
                            ),
                            style: isEnglish
                                ? GoogleFonts.ebGaramond(
                                    fontSize: textSize,
                                    height: 1.7,
                                  )
                                : ethiopic(size: textSize),
                          ),
                        ],
                        if (item.special.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            isEnglish
                                ? 'Hymn of Praise to Mary for ${_daysEn[widget.day]}'
                                : item.special,
                            style: isEnglish
                                ? GoogleFonts.ebGaramond(
                                    fontSize: textSize,
                                    height: 1.7,
                                  )
                                : ethiopic(size: textSize),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item.psalmChapters.isNotEmpty ||
                      item.midnightPsalmChapters.isNotEmpty)
                    section(
                      localizedText(language, 'መዝሙረ ዳዊት', 'Psalm'),
                      Column(
                        children: [
                          for (final chapter in [
                            ...item.psalmChapters,
                            ...item.midnightPsalmChapters,
                          ])
                            _PsalmChapterCard(
                              chapter: chapter,
                              language: language,
                              textSize: textSize,
                            ),
                        ],
                      ),
                    ),
                  section(
                    localizedText(language, 'ንባብ', 'Bible Reading'),
                    Column(
                      children: [
                        for (final ref in item.readings)
                          _BibleReadingCard(
                            referenceText: _referenceLabel(
                              _referenceFor(ref),
                              ref,
                              language,
                            ),
                            reference: _referenceFor(ref),
                            language: language,
                            textSize: textSize,
                          ),
                      ],
                    ),
                  ),
                  MetaniaCounter(
                    prayerHourId: widget.hour,
                    enabled: !_isUpcomingHour,
                  ),
                  section(
                    localizedText(language, 'መዝጊያ ጸሎት', 'Closing prayer'),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEnglish
                              ? _closingOurFatherEnglish
                              : _closingOurFather,
                          style: isEnglish
                              ? GoogleFonts.ebGaramond(
                                  fontSize: textSize,
                                  height: 1.7,
                                )
                              : ethiopic(size: textSize),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          isEnglish
                              ? _closingMarianPrayerEnglish
                              : _closingMarianPrayer,
                          style: isEnglish
                              ? GoogleFonts.ebGaramond(
                                  fontSize: textSize,
                                  height: 1.7,
                                )
                              : ethiopic(size: textSize),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showCelebration)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: colors.scrim.withValues(alpha: 0.34),
                  child: SafeArea(
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.72, end: 1),
                        duration: const Duration(milliseconds: 620),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) => Opacity(
                          opacity: scale.clamp(0, 1),
                          child: Transform.scale(scale: scale, child: child),
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: colors.tertiary.withValues(alpha: 0.42),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.scrim.withValues(alpha: 0.2),
                                blurRadius: 32,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.tertiaryContainer,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 42,
                                  color: colors.onTertiaryContainer,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                localizedText(
                                  language,
                                  'ጸሎቱ ተጠናቋል',
                                  'Prayer complete',
                                ),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cinzel(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                localizedText(
                                  language,
                                  'መልካም ሥራ። ወደ ሰዓታት በመመለስ ላይ…',
                                  'Well done. Returning to Hours…',
                                ),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SizedBox(
                width: double.infinity,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: done ? 1 : 0),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeInOutCubic,
                  builder: (context, progress, _) {
                    final background = Color.lerp(
                      colors.primary,
                      colors.tertiary,
                      progress,
                    )!;
                    final foreground = Color.lerp(
                      colors.onPrimary,
                      colors.onTertiary,
                      progress,
                    )!;
                    return FilledButton.icon(
                      onPressed: _leavingAfterCompletion || _isUpcomingHour
                          ? null
                          : _toggle,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 360),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: CurvedAnimation(
                                parent: animation,
                                curve: Curves.elasticOut,
                              ),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: Icon(
                          done
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          key: ValueKey(done),
                        ),
                      ),
                      label: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.25),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          _isUpcomingHour
                              ? localizedText(
                                  language,
                                  'ጊዜው ሲደርስ ይከፈታል',
                                  'Locked until prayer time',
                                )
                              : done
                              ? localizedText(
                                  language,
                                  'ተጠናቋል - መልስ',
                                  'Completed - undo',
                                )
                              : localizedText(
                                  language,
                                  'ጸሎቱን ጨርሻለሁ',
                                  'Mark prayer complete',
                                ),
                          key: ValueKey('completion-label-$done'),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: background,
                        foregroundColor: foreground,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Loads full Psalm text from the bundled book 19 asset through BibleRepository.
final Map<String, Future<BibleChapter>> _psalmTextCache = {};

class _PsalmChapterCard extends StatelessWidget {
  const _PsalmChapterCard({
    required this.chapter,
    required this.language,
    this.textSize = 19,
  });
  final int chapter;
  final String language;
  final double textSize;

  @override
  Widget build(BuildContext context) => Card(
    child: FutureBuilder<BibleChapter>(
      future: _psalmTextCache.putIfAbsent(
        '$chapter:$language',
        () => const BibleRepository().getChapter(
          'psalms',
          chapter,
          language: language == 'eth'
              ? BibleLanguage.amharic
              : BibleLanguage.english,
        ),
      ),
      builder: (context, snapshot) {
        final verses = snapshot.data?.verses;
        return ExpansionTile(
          title: Text(
            localizedText(language, 'መዝሙር $chapter', 'Psalm $chapter'),
          ),
          subtitle: snapshot.connectionState == ConnectionState.waiting
              ? Text(localizedText(language, 'መዝሙር በመጫን ላይ…', 'Loading Psalm…'))
              : snapshot.hasError
              ? Text(
                  localizedText(
                    language,
                    'የመዝሙሩን ጽሑፍ መክፈት አልተቻለም።',
                    'Could not load this Psalm.',
                  ),
                )
              : Text(
                  localizedText(
                    language,
                    '${verses?.length ?? 0} ቁጥሮች',
                    '${verses?.length ?? 0} verses',
                  ),
                ),
          children: [
            if (verses != null)
              for (final verse in verses)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${verse.verse}.  ${language == 'eth' ? verse.amharicText : verse.englishText ?? 'English text unavailable.'}',
                      style: language == 'eth'
                          ? TextStyle(
                              fontFamily: 'AbyssinicaSIL',
                              fontSize: textSize,
                              height: 1.85,
                            )
                          : GoogleFonts.ebGaramond(
                              fontSize: textSize,
                              height: 1.7,
                            ),
                    ),
                  ),
                ),
          ],
        );
      },
    ),
  );
}

BibleReference? _referenceFor(String text) {
  const values = <String, (String, int, int, int)>{
    'ማቴዎስ 27፥1-2': ('book_40', 27, 1, 2),
    'መዝሙር 5፥3': ('psalms', 5, 3, 3),
    'ዮሐንስ 19፥1': ('book_43', 19, 1, 1),
    'ሐዋርያት ሥራ 2፥15': ('book_44', 2, 15, 15),
    'ሉቃስ 1፥28': ('book_42', 1, 28, 28),
    'ዳንኤል 6፥10': ('book_27', 6, 10, 10),
    'ዮሐንስ 19፥23-29': ('book_43', 19, 23, 29),
    'ማርቆስ 15፥34-38': ('book_41', 15, 34, 38),
    'ማቴዎስ 27፥50': ('book_40', 27, 50, 50),
    'ሐዋርያት ሥራ 10፥1-4': ('book_44', 10, 1, 4),
    'ማቴዎስ 27፥58-60': ('book_40', 27, 58, 60),
    'ሉቃስ 11፥1-4': ('book_42', 11, 1, 4),
    'ማቴዎስ 26፥47-51': ('book_40', 26, 47, 51),
    'ማቴዎስ 25፥6': ('book_40', 25, 6, 6),
    'ሐዋርያት ሥራ 16፥25': ('book_44', 16, 25, 25),
  };
  final normalized = text;
  final all = _readings.expand((group) => group).toList(growable: false);
  final i = all.indexOf(normalized);
  const ordered = <(String, int, int, int)>[
    ('book_40', 27, 1, 2),
    ('psalms', 5, 3, 3),
    ('book_43', 19, 1, 1),
    ('book_44', 2, 15, 15),
    ('book_42', 1, 28, 28),
    ('book_27', 6, 10, 10),
    ('book_43', 19, 23, 29),
    ('book_41', 15, 34, 38),
    ('book_40', 27, 50, 50),
    ('book_44', 10, 1, 4),
    ('book_40', 27, 58, 60),
    ('book_42', 11, 1, 4),
    ('book_40', 26, 47, 51),
    ('book_40', 25, 6, 6),
    ('book_44', 16, 25, 25),
  ];
  final value = values[normalized] ?? (i < 0 ? null : ordered[i]);
  return value == null
      ? null
      : BibleReference(
          bookId: value.$1,
          chapter: value.$2,
          startVerse: value.$3,
          endVerse: value.$4,
          label: text,
        );
}

class _BibleReadingCard extends StatelessWidget {
  const _BibleReadingCard({
    required this.referenceText,
    required this.reference,
    required this.language,
    this.textSize = 19,
  });
  final String referenceText;
  final BibleReference? reference;
  final String language;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    if (reference == null) {
      return Card(
        child: ListTile(
          title: Text(referenceText),
          subtitle: Text(
            localizedText(
              language,
              'የመጽሐፍ ቅዱስ ምንጭ አልተገኘም።',
              'Reference text is unavailable.',
            ),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: FutureBuilder<List<BibleVerse>>(
          future: const BibleRepository().getPassage(
            reference!,
            language: language == 'eth'
                ? BibleLanguage.amharic
                : BibleLanguage.english,
          ),
          builder: (context, snapshot) {
            final verses = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        referenceText,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: localizedText(
                        language,
                        'መጽሐፍ ቅዱስን ክፈት',
                        'Open Bible passage',
                      ),
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/bible',
                        arguments: reference,
                      ),
                    ),
                  ],
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(),
                if (snapshot.hasError)
                  Text(
                    localizedText(
                      language,
                      'ይህን ንባብ መጫን አልተቻለም።',
                      'Unable to load this passage.',
                    ),
                  ),
                if (verses != null)
                  for (final verse in verses)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${verse.verse}.  ${language == 'eth' ? verse.amharicText : verse.englishText ?? 'English text unavailable.'}',
                        style: language == 'eth'
                            ? TextStyle(
                                fontFamily: 'AbyssinicaSIL',
                                fontSize: textSize,
                                height: 1.85,
                              )
                            : GoogleFonts.ebGaramond(
                                fontSize: textSize,
                                height: 1.7,
                              ),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}
