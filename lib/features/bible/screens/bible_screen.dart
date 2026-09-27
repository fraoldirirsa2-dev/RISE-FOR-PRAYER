import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rise_for_prayer/features/bible/models/bible_models.dart';
import 'package:rise_for_prayer/features/bible/providers/bible_provider.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:rise_for_prayer/utils/localization.dart';

class BibleScreen extends ConsumerStatefulWidget {
  const BibleScreen({super.key, this.initialReference});

  final BibleReference? initialReference;

  @override
  ConsumerState<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends ConsumerState<BibleScreen> {
  String? _selectedBook;
  int? _selectedChapter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final reference = widget.initialReference;
      if (reference == null || !mounted) return;
      final provider = ref.read(bibleProvider);
      await provider.loadBooks();
      if (!mounted ||
          provider.books.every((book) => book.id != reference.bookId)) {
        return;
      }
      setState(() {
        _selectedBook = reference.bookId;
        _selectedChapter = reference.chapter;
      });
      await provider.loadChapter(
        reference.bookId,
        reference.chapter,
        language: _bibleLanguage(ref.read(settingsProvider).language),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bible = ref.watch(bibleProvider);
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final chapter = bible.chapter;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizedText(settings.language, 'መጽሐፍ ቅዱስ', 'Bible'),
          style: GoogleFonts.cinzel(fontSize: 18),
        ),
      ),
      body: bible.error != null && bible.books.isEmpty
          ? _unavailable(bible.error!, settings.language)
          : Column(
              children: [
                _selectors(bible, settings.language),
                if (bible.loading) const LinearProgressIndicator(),
                Expanded(
                  child: chapter == null
                      ? Center(
                          child: Text(
                            localizedText(
                              settings.language,
                              'መጽሐፍ እና ምዕራፍ ይምረጡ',
                              'Select a book and chapter',
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: chapter.verses.length,
                          itemBuilder: (context, index) {
                            final verse = chapter.verses[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontSize: 19,
                                    height: 1.65,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '${verse.verse}  ',
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (settings.language == 'eth')
                                      TextSpan(text: verse.amharicText),
                                    if (settings.language == 'en')
                                      TextSpan(
                                        text:
                                            verse.englishText ??
                                            localizedText(
                                              settings.language,
                                              'የእንግሊዝኛ ትርጉም አልተገኘም።',
                                              'English translation unavailable.',
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _selectors(BibleProvider bible, String language) {
    final matchingBooks = bible.books.where((item) => item.id == _selectedBook);
    final book = matchingBooks.isEmpty ? null : matchingBooks.first;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedBook,
              hint: Text(localizedText(language, 'መጽሐፍ', 'Book')),
              items: bible.books
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        language == 'eth'
                            ? item.amharicName
                            : item.englishName,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedBook = value;
                _selectedChapter = null;
              }),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              value: _selectedChapter,
              hint: Text(localizedText(language, 'ምዕራፍ', 'Chapter')),
              items: book == null
                  ? const []
                  : List.generate(
                      book.chapterCount,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
              onChanged: _selectedBook == null
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _selectedChapter = value);
                      ref
                          .read(bibleProvider)
                          .loadChapter(
                            _selectedBook!,
                            value,
                            language: _bibleLanguage(language),
                          );
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _unavailable(String message, String language) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '$message\n\n${localizedText(language, 'የተፈቀደ የአማርኛ እና የእንግሊዝኛ ምንጭ ሲጨመር ይህ ክፍል ይሰራል።', 'Add an authorized Amharic and English source to enable offline Bible reading.')}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  BibleLanguage _bibleLanguage(String language) {
    if (language == 'eth') return BibleLanguage.amharic;
    if (language == 'en') return BibleLanguage.english;
    return BibleLanguage.both;
  }
}
