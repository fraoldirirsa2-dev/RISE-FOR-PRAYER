enum BibleLanguage { amharic, english, both }

class BibleVerse {
  const BibleVerse({
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.amharicText,
    this.englishText,
  });

  final String bookId;
  final String bookName;
  final int chapter;
  final int verse;
  final String amharicText;
  final String? englishText;
}

class BibleChapter {
  const BibleChapter({
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verses,
  });

  final String bookId;
  final String bookName;
  final int chapter;
  final List<BibleVerse> verses;
}

class BiblePassage {
  const BiblePassage({required this.reference, required this.verses});

  final BibleReference reference;
  final List<BibleVerse> verses;
}

class BibleBook {
  const BibleBook({
    required this.id,
    required this.amharicName,
    required this.englishName,
    required this.chapterCount,
  });

  final String id;
  final String amharicName;
  final String englishName;
  final int chapterCount;
}

class BibleReference {
  const BibleReference({
    required this.bookId,
    required this.chapter,
    this.startVerse,
    this.endVerse,
    this.label,
  });

  final String bookId;
  final int chapter;
  final int? startVerse;
  final int? endVerse;
  final String? label;

  const BibleReference.psalm(int chapter)
    : this(bookId: 'psalms', chapter: chapter, label: 'Psalm $chapter');

  @override
  bool operator ==(Object other) =>
      other is BibleReference &&
      other.bookId == bookId &&
      other.chapter == chapter &&
      other.startVerse == startVerse &&
      other.endVerse == endVerse;

  @override
  int get hashCode => Object.hash(bookId, chapter, startVerse, endVerse);
}
