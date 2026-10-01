import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/data/prayer_content.dart';
import 'package:rise_for_prayer/features/weekly_prayer_rule/weekly_prayer_rule.dart';

void main() {
  test('provides typed content for all seven canonical hours', () {
    expect(prayerReadings, hasLength(7));
    expect(
      prayerReadings.every((reading) => reading.sections.isNotEmpty),
      isTrue,
    );
    expect(
      prayerReadings.every(
        (reading) => reading.sections.every(
          (section) =>
              section.title.isNotEmpty &&
              section.amharic.isNotEmpty &&
              section.english.isNotEmpty,
        ),
      ),
      isTrue,
    );
  });

  testWidgets('opening prayer omits the Marian prayer in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyPrayerRuleReading(day: 0, hour: 0, language: 'en'),
            ),
          ),
        ),
      ),
    );

    final openingPrayer = find
        .ancestor(
          of: find.text('Opening Prayer'),
          matching: find.byType(Container),
        )
        .first;
    expect(
      find.descendant(of: openingPrayer, matching: find.text('Marian prayer')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: openingPrayer,
        matching: find.textContaining('O my Lady Mary I salute you'),
      ),
      findsNothing,
    );
  });

  testWidgets('opening prayer omits the Marian prayer in Amharic', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyPrayerRuleReading(day: 0, hour: 0, language: 'eth'),
            ),
          ),
        ),
      ),
    );

    final openingPrayer = find
        .ancestor(of: find.text('መክፈቻ ጸሎት'), matching: find.byType(Container))
        .first;
    expect(
      find.descendant(of: openingPrayer, matching: find.text('የማርያም ጸሎት')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: openingPrayer,
        matching: find.textContaining('እመቤታችን ቅድስት ድንግል ማርያም ሆይ'),
      ),
      findsNothing,
    );
  });

  test('defines the canonical Psalm references without duplicating text', () {
    final expected = [
      [51, 63, 64, 69, 118],
      [51, 62, 66, 67, 148, 149, 150],
      [51, 19, 20, 21, 22, 23],
      [51, 54, 55, 56, 90, 91],
      [51, 83, 84, 85, 86, 87],
      [51, 116, 117, 118],
      [51, 129, 130, 131, 132, 133],
    ];
    expect(
      prayerReadings
          .map(
            (reading) =>
                reading.readings.map((reference) => reference.chapter).toList(),
          )
          .toList(),
      expected,
    );
    expect(
      prayerReadings
          .expand((reading) => reading.readings)
          .every((reference) => reference.bookId == 'psalms'),
      isTrue,
    );
  });

  test('provides a Psalm for every weekday and prayer hour', () {
    expect(weeklyPrayerRule, hasLength(7));
    for (final day in weeklyPrayerRule) {
      expect(day, hasLength(7));
      for (final hour in day) {
        expect([
          ...hour.psalmChapters,
          ...hour.midnightPsalmChapters,
        ], isNotEmpty);
      }
    }
  });

  test('rotates Scripture per hour while staying stable for the same day', () {
    final first = prayerReadingsForDate(DateTime(2026, 9, 12));
    final sameDay = prayerReadingsForDate(DateTime(2026, 9, 12, 23, 59));
    final nextDay = prayerReadingsForDate(DateTime(2026, 9, 13));

    expect(first, hasLength(7));
    expect(
      first.map((reading) => reading.readings).toList(),
      equals(sameDay.map((reading) => reading.readings).toList()),
    );
    expect(
      first.map((reading) => reading.dailyReadings).toList(),
      isNot(equals(nextDay.map((reading) => reading.dailyReadings).toList())),
    );
    expect(
      first.every(
        (reading) =>
            reading.dailyReadings.isNotEmpty &&
            reading.dailyReadings.every(
              (reference) => reference.bookId == 'psalms',
            ),
      ),
      isTrue,
    );
  });
}
