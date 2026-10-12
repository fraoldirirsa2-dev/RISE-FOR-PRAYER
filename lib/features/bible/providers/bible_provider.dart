import 'package:flutter/foundation.dart';
import 'package:rise_for_prayer/features/bible/models/bible_models.dart';
import 'package:rise_for_prayer/features/bible/repositories/bible_repository.dart';

class BibleProvider extends ChangeNotifier {
  BibleProvider({BibleRepository? repository, bool autoLoad = false})
    : _repository = repository ?? const BibleRepository() {
    if (autoLoad) {
      loadBooks();
    }
  }

  final BibleRepository _repository;
  List<BibleBook> _books = const [];
  BibleChapter? _chapter;
  final _passages = <String, List<BibleVerse>>{};
  final _passageErrors = <String, String>{};
  String? _error;
  bool _loading = false;

  List<BibleBook> get books => _books;
  BibleChapter? get chapter => _chapter;
  String? get error => _error;
  bool get loading => _loading;
  List<BibleVerse>? passageFor(
    BibleReference reference, {
    BibleLanguage language = BibleLanguage.both,
  }) => _passages[_passageKey(reference, language)];
  String? passageErrorFor(
    BibleReference reference, {
    BibleLanguage language = BibleLanguage.both,
  }) => _passageErrors[_passageKey(reference, language)];

  Future<void>? _loadBooksFuture;

  Future<void> loadBooks() {
    return _loadBooksFuture ??= _doLoadBooks();
  }

  Future<void> _doLoadBooks() async {
    _loading = true;
    notifyListeners();
    try {
      _books = await _repository.getBooks();
      _error = null;
    } on BibleSourceException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      _loadBooksFuture = null;
      notifyListeners();
    }
  }

  Future<void> loadChapter(
    String bookId,
    int chapter, {
    BibleLanguage language = BibleLanguage.both,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _chapter = await _repository.getChapter(
        bookId,
        chapter,
        language: language,
      );
    } on BibleSourceException catch (error) {
      _error = error.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadPassage(
    BibleReference reference, {
    BibleLanguage language = BibleLanguage.both,
  }) async {
    final key = _passageKey(reference, language);
    _loading = true;
    _passageErrors.remove(key);
    notifyListeners();
    try {
      final passage = await _repository.getPassage(
        reference,
        language: language,
      );
      if (passage.isEmpty) {
        throw const BibleSourceException(
          'No Scripture content available for this reference.',
        );
      }
      _passages[key] = passage;
    } on BibleSourceException catch (error) {
      _passageErrors[key] = error.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String _passageKey(BibleReference reference, BibleLanguage language) =>
      '${reference.bookId}:${reference.chapter}:${reference.startVerse ?? ''}:'
      '${reference.endVerse ?? ''}:${language.name}';
}
