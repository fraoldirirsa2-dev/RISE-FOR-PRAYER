import 'package:flutter_test/flutter_test.dart';

import 'dart:math';

import 'package:rise_for_prayer/features/bible/models/bible_models.dart';
import 'package:rise_for_prayer/features/bible/providers/daily_scripture_provider.dart';
import 'package:rise_for_prayer/features/bible/providers/bible_provider.dart';
import 'package:rise_for_prayer/features/bible/repositories/bible_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing offline corpus becomes an explicit provider error', () async {
    final provider = BibleProvider(
      repository: const BibleRepository(assetPath: 'assets/bible/missing.json'),
    );

    await provider.loadBooks();

    expect(provider.books, isEmpty);
    expect(provider.error, contains('No Bible book files'));
  });

  test('references support verse ranges and stable passage cache keys', () {
    const first = BibleReference(
      bookId: 'psalms',
      chapter: 51,
      startVerse: 1,
      endVerse: 5,
    );
    const second = BibleReference(
      bookId: 'psalms',
      chapter: 51,
      startVerse: 1,
      endVerse: 5,
    );

    expect(first, equals(second));
    expect(first.hashCode, equals(second.hashCode));
  });

  test(
    'BibleProvider keeps Amharic and English passage caches distinct',
    () async {
      final provider = BibleProvider(repository: const BibleRepository());
      const reference = BibleReference.psalm(51);

      await provider.loadPassage(reference, language: BibleLanguage.amharic);
      expect(
        provider.passageFor(reference, language: BibleLanguage.amharic),
        isNotNull,
      );
      expect(
        provider.passageFor(reference, language: BibleLanguage.english),
        isNull,
      );

      await provider.loadPassage(reference, language: BibleLanguage.english);
      expect(
        provider.passageFor(reference, language: BibleLanguage.english),
        isNotNull,
      );
    },
  );

  test('loads the supplied Bible assets and resolves Psalm 51', () async {
    const repository = BibleRepository();

    final books = await repository.getBooks();
    final chapter = await repository.getChapter('psalms', 51);

    expect(books, hasLength(66));
    expect(books.any((book) => book.id == 'psalms'), isTrue);
    expect(chapter.verses, isNotEmpty);
    expect(chapter.verses.first.amharicText.trim(), isNotEmpty);
    expect(chapter.verses.first.englishText, contains('Have mercy upon me'));
  });

  test('resolves every Psalm chapter referenced by prayer content', () async {
    const repository = BibleRepository();
    const referencedPsalms = [
      19,
      20,
      21,
      22,
      23,
      51,
      54,
      55,
      56,
      62,
      63,
      64,
      66,
      67,
      69,
      83,
      84,
      85,
      86,
      87,
      90,
      91,
      116,
      117,
      118,
      148,
      149,
      150,
    ];

    for (final psalm in referencedPsalms) {
      final chapter = await repository.getChapter('psalms', psalm);
      expect(chapter.verses, isNotEmpty, reason: 'Psalm $psalm is empty');
    }
  });

  test(
    'persists daily Scripture and refreshes to another real passage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final date = DateTime(2026, 9, 12, 8);
      final first = DailyScriptureProvider(
        clock: () => date,
        random: Random(4),
      );
      await first.loadDaily();
      final firstReference = first.passage!.reference;

      final restored = DailyScriptureProvider(
        clock: () => date,
        random: Random(99),
      );
      await restored.loadDaily();
      expect(restored.passage!.reference, equals(firstReference));

      await restored.refresh();
      expect(restored.passage, isNotNull);
      expect(restored.passage!.verses, isNotEmpty);
      expect(restored.passage!.reference, isNot(equals(firstReference)));
    },
  );
}
