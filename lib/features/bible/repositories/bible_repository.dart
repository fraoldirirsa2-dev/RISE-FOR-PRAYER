import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:rise_for_prayer/features/bible/models/bible_models.dart';

class BibleSourceException implements Exception {
  const BibleSourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads the individual Amharic book JSON files bundled under assets/bible/.
class BibleRepository {
  const BibleRepository({this.assetPath = 'assets/bible/'});

  static final Map<String, Future<Map<String, dynamic>>> _bookDataCache = {};
  static final Map<String, Future<List<BibleBook>>> _booksCache = {};
  static Future<List<dynamic>>? _englishBibleCache;
  static Future<List<String>>? _assetManifestCache;

  final String assetPath;

  Future<List<BibleBook>> getBooks() =>
      _booksCache.putIfAbsent(assetPath, _loadBooks);

  Future<List<BibleBook>> _loadBooks() async {
    final paths = await _bookAssetPaths();
    final data = await Future.wait(paths.map(_loadBook));
    return List.unmodifiable(
      List<BibleBook>.generate(paths.length, (index) {
        final book = data[index];
        final id = _bookId(paths[index]);
        return BibleBook(
          id: id,
          amharicName: book['title'] as String,
          englishName: _englishBookNames[id] ?? book['title'] as String,
          chapterCount: (book['chapters'] as List<dynamic>).length,
        );
      }),
    );
  }

  Future<BibleChapter> getChapter(
    String bookId,
    int chapter, {
    BibleLanguage language = BibleLanguage.both,
  }) async {
    final path = await _pathForBook(bookId);
    final data = await _loadBook(path);
    final chapters = data['chapters'];
    if (chapters is! List<dynamic>) {
      throw BibleSourceException('Invalid chapter data in $path.');
    }
    final matching = chapters.cast<Map<String, dynamic>>().where(
      (item) => item['chapter'].toString() == chapter.toString(),
    );
    if (matching.isEmpty) {
      throw BibleSourceException('Bible chapter not found: $bookId $chapter');
    }

    final selected = matching.first;
    final rawVerses = selected['verses'];
    if (rawVerses is! List<dynamic> || rawVerses.isEmpty) {
      throw BibleSourceException('Bible chapter is empty: $bookId $chapter');
    }
    final title = data['title'] as String;
    final englishVerses = language == BibleLanguage.amharic
        ? const <String>[]
        : await _englishVerses(bookId, chapter);
    // Amharic and KJV versification differs in a number of chapters. Only
    // attach English text when both source chapters have the same verse count;
    // otherwise index-based pairing could display the wrong verse as a match.
    final englishIsAligned = englishVerses.length == rawVerses.length;
    return BibleChapter(
      bookId: bookId,
      bookName: title,
      chapter: chapter,
      verses: rawVerses
          .asMap()
          .entries
          .map(
            (entry) => _parseVerse(
              entry.value,
              bookId: bookId,
              bookName: title,
              chapter: chapter,
              verse: entry.key + 1,
              englishText: englishIsAligned && entry.key < englishVerses.length
                  ? englishVerses[entry.key]
                  : null,
            ),
          )
          .whereType<BibleVerse>()
          .toList(growable: false),
    );
  }

  Future<List<BibleVerse>> getVerses(
    String bookId,
    int chapter, {
    BibleLanguage language = BibleLanguage.both,
  }) async => (await getChapter(bookId, chapter, language: language)).verses;

  Future<List<BibleVerse>> getPassage(
    BibleReference reference, {
    BibleLanguage language = BibleLanguage.both,
  }) async {
    final verses = await getVerses(
      reference.bookId,
      reference.chapter,
      language: language,
    );
    final start = reference.startVerse ?? 1;
    final end = reference.endVerse ?? reference.startVerse ?? verses.last.verse;
    return verses
        .where((verse) => verse.verse >= start && verse.verse <= end)
        .toList(growable: false);
  }

  Future<BiblePassage> getRandomPassage({Random? random}) async {
    final source = random ?? Random();
    final paths = await _bookAssetPaths();
    for (var attempt = 0; attempt < 12; attempt++) {
      final path = paths[source.nextInt(paths.length)];
      final bookData = await _loadBook(path);
      final chapterCount = (bookData['chapters'] as List<dynamic>).length;
      if (chapterCount == 0) continue;
      final bookId = _bookId(path);
      final chapter = source.nextInt(chapterCount) + 1;
      final verses = await getVerses(bookId, chapter);
      if (verses.isEmpty) continue;
      final startIndex = source.nextInt(verses.length);
      final length = min(3, verses.length - startIndex);
      final selected = verses.sublist(startIndex, startIndex + length);
      final reference = BibleReference(
        bookId: bookId,
        chapter: chapter,
        startVerse: selected.first.verse,
        endVerse: selected.last.verse,
        label:
            '${bookData['title']} $chapter:${selected.first.verse}'
            '${length > 1 ? '-${selected.last.verse}' : ''}',
      );
      return BiblePassage(reference: reference, verses: selected);
    }
    throw const BibleSourceException('Unable to select Scripture. Try again.');
  }

  Future<List<String>> _bookAssetPaths() async {
    final manifest = await _assetManifest();
    final prefix = assetPath.endsWith('/') ? assetPath : '$assetPath/';
    final paths =
        manifest
            .where(
              (path) =>
                  path.startsWith(prefix) &&
                  RegExp(r'^\d{2}_').hasMatch(path.split('/').last) &&
                  path.endsWith('.json'),
            )
            .toList()
          ..sort();
    if (paths.isEmpty) {
      throw const BibleSourceException(
        'No Bible book files were found under assets/bible/.',
      );
    }
    return paths;
  }

  Future<String> _pathForBook(String bookId) async {
    final paths = await _bookAssetPaths();
    final number = bookId == 'psalms'
        ? 19
        : int.tryParse(bookId.replaceFirst('book_', ''));
    final path = paths.firstWhere(
      (item) => int.tryParse(item.split('/').last.split('_').first) == number,
      orElse: () => throw BibleSourceException('Bible book not found: $bookId'),
    );
    return path;
  }

  Future<Map<String, dynamic>> _loadBook(String path) =>
      _bookDataCache.putIfAbsent(path, () async {
        final dynamic decoded;
        try {
          decoded = jsonDecode(await rootBundle.loadString(path));
        } on FormatException {
          throw BibleSourceException('Bible dataset is not valid JSON: $path');
        } catch (_) {
          throw BibleSourceException('Unable to load Bible asset: $path');
        }
        if (decoded is! Map<String, dynamic> ||
            decoded['title'] is! String ||
            decoded['chapters'] is! List<dynamic>) {
          throw BibleSourceException('Invalid Bible book format: $path');
        }
        return decoded;
      });

  Future<List<String>> _englishVerses(String bookId, int chapter) async {
    final abbreviation = _englishAbbreviations[bookId];
    if (abbreviation == null) return const [];
    final decoded = await (_englishBibleCache ??= _loadEnglishBible());
    if (decoded.isEmpty) return const [];
    for (final book in decoded) {
      if (book is Map<String, dynamic> && book['abbrev'] == abbreviation) {
        final chapters = book['chapters'];
        if (chapters is List<dynamic> &&
            chapter > 0 &&
            chapter <= chapters.length) {
          final verses = chapters[chapter - 1];
          if (verses is List<dynamic>) {
            return verses.whereType<String>().toList(growable: false);
          }
        }
      }
    }
    return const [];
  }

  Future<List<dynamic>> _loadEnglishBible() async {
    try {
      final source = await rootBundle.loadString('assets/bible/en_kjv.json');
      final decoded = jsonDecode(source.replaceFirst('\uFEFF', ''));
      return decoded is List<dynamic> ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> _assetManifest() => _assetManifestCache ??=
      AssetManifest.loadFromAssetBundle(
        rootBundle,
      ).then((manifest) => manifest.listAssets());

  String _bookId(String path) {
    final number = path.split('/').last.split('_').first;
    return number == '19' ? 'psalms' : 'book_$number';
  }

  BibleVerse? _parseVerse(
    Object? value, {
    required String bookId,
    required String bookName,
    required int chapter,
    required int verse,
    String? englishText,
  }) {
    if (value is! String) {
      throw BibleSourceException(
        'Invalid Bible verse in $bookId chapter $chapter at $verse.',
      );
    }
    if (value.trim().isEmpty) return null;
    return BibleVerse(
      bookId: bookId,
      bookName: bookName,
      chapter: chapter,
      verse: verse,
      amharicText: value,
      englishText: englishText,
    );
  }
}

String englishBibleBookName(String bookId) =>
    _englishBookNames[bookId] ?? bookId;

const _englishBookNames = <String, String>{
  'book_01': 'Genesis',
  'book_02': 'Exodus',
  'book_03': 'Leviticus',
  'book_04': 'Numbers',
  'book_05': 'Deuteronomy',
  'book_06': 'Joshua',
  'book_07': 'Judges',
  'book_08': 'Ruth',
  'book_09': '1 Samuel',
  'book_10': '2 Samuel',
  'book_11': '1 Kings',
  'book_12': '2 Kings',
  'book_13': '1 Chronicles',
  'book_14': '2 Chronicles',
  'book_15': 'Ezra',
  'book_16': 'Nehemiah',
  'book_17': 'Esther',
  'book_18': 'Job',
  'psalms': 'Psalms',
  'book_20': 'Proverbs',
  'book_21': 'Ecclesiastes',
  'book_22': 'Song of Solomon',
  'book_23': 'Isaiah',
  'book_24': 'Jeremiah',
  'book_25': 'Lamentations',
  'book_26': 'Ezekiel',
  'book_27': 'Daniel',
  'book_28': 'Hosea',
  'book_29': 'Joel',
  'book_30': 'Amos',
  'book_31': 'Obadiah',
  'book_32': 'Jonah',
  'book_33': 'Micah',
  'book_34': 'Nahum',
  'book_35': 'Habakkuk',
  'book_36': 'Zephaniah',
  'book_37': 'Haggai',
  'book_38': 'Zechariah',
  'book_39': 'Malachi',
  'book_40': 'Matthew',
  'book_41': 'Mark',
  'book_42': 'Luke',
  'book_43': 'John',
  'book_44': 'Acts',
  'book_45': 'Romans',
  'book_46': '1 Corinthians',
  'book_47': '2 Corinthians',
  'book_48': 'Galatians',
  'book_49': 'Ephesians',
  'book_50': 'Philippians',
  'book_51': 'Colossians',
  'book_52': '1 Thessalonians',
  'book_53': '2 Thessalonians',
  'book_54': '1 Timothy',
  'book_55': '2 Timothy',
  'book_56': 'Titus',
  'book_57': 'Philemon',
  'book_58': 'Hebrews',
  'book_59': 'James',
  'book_60': '1 Peter',
  'book_61': '2 Peter',
  'book_62': '1 John',
  'book_63': '2 John',
  'book_64': '3 John',
  'book_65': 'Jude',
  'book_66': 'Revelation',
};

const _englishAbbreviations = <String, String>{
  'book_01': 'gn',
  'book_02': 'ex',
  'book_03': 'lv',
  'book_04': 'nm',
  'book_05': 'dt',
  'book_06': 'js',
  'book_07': 'jud',
  'book_08': 'rt',
  'book_09': '1sm',
  'book_10': '2sm',
  'book_11': '1kgs',
  'book_12': '2kgs',
  'book_13': '1ch',
  'book_14': '2ch',
  'book_15': 'ezr',
  'book_16': 'ne',
  'book_17': 'et',
  'book_18': 'job',
  'psalms': 'ps',
  'book_20': 'prv',
  'book_21': 'ec',
  'book_22': 'so',
  'book_23': 'is',
  'book_24': 'jr',
  'book_25': 'lm',
  'book_26': 'ez',
  'book_27': 'dn',
  'book_28': 'ho',
  'book_29': 'jl',
  'book_30': 'am',
  'book_31': 'ob',
  'book_32': 'jn',
  'book_33': 'mi',
  'book_34': 'na',
  'book_35': 'hk',
  'book_36': 'zp',
  'book_37': 'hg',
  'book_38': 'zc',
  'book_39': 'ml',
  'book_40': 'mt',
  'book_41': 'mk',
  'book_42': 'lk',
  'book_43': 'jo',
  'book_44': 'act',
  'book_45': 'rm',
  'book_46': '1co',
  'book_47': '2co',
  'book_48': 'gl',
  'book_49': 'eph',
  'book_50': 'ph',
  'book_51': 'cl',
  'book_52': '1ts',
  'book_53': '2ts',
  'book_54': '1tm',
  'book_55': '2tm',
  'book_56': 'tt',
  'book_57': 'phm',
  'book_58': 'hb',
  'book_59': 'jm',
  'book_60': '1pe',
  'book_61': '2pe',
  'book_62': '1jo',
  'book_63': '2jo',
  'book_64': '3jo',
  'book_65': 'jd',
  'book_66': 're',
};
