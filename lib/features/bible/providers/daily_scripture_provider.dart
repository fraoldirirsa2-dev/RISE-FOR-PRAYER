import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rise_for_prayer/features/bible/models/bible_models.dart';
import 'package:rise_for_prayer/features/bible/repositories/bible_repository.dart';
import 'package:rise_for_prayer/services/time_service.dart';

class DailyScriptureProvider extends ChangeNotifier {
  DailyScriptureProvider({
    BibleRepository? repository,
    DateTime Function()? clock,
    Random? random,
  }) : _repository = repository ?? const BibleRepository(),
       _clock = clock ?? TimeService.currentNow,
       _random = random ?? Random() {
    loadDaily();
    _scriptureTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_disposed) refresh();
    });
  }

  static const _dateKey = 'daily_scripture_date';
  static const _bookKey = 'daily_scripture_book';
  static const _chapterKey = 'daily_scripture_chapter';
  static const _startKey = 'daily_scripture_start';
  static const _endKey = 'daily_scripture_end';

  final BibleRepository _repository;
  final DateTime Function() _clock;
  final Random _random;
  BiblePassage? _passage;
  String? _error;
  bool _loading = false;
  Timer? _scriptureTimer;

  BiblePassage? get passage => _passage;
  String? get error => _error;
  bool get loading => _loading;

  Future<void> loadDaily() async {
    if (_loading || _disposed) return;
    _loading = true;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      final today = _dateOnly(_clock());
      final savedDate = preferences.getString(_dateKey);
      if (savedDate == _dateString(today)) {
        final saved = await _loadSavedPassage(preferences);
        if (saved != null) {
          _passage = saved;
          _error = null;
          return;
        }
      }
      await _selectAndPersist(preferences);
    } on BibleSourceException catch (error) {
      _error = error.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _scriptureTimer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (_loading || _disposed) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await _selectAndPersist(preferences);
    } on BibleSourceException catch (error) {
      _error = error.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _selectAndPersist(SharedPreferences preferences) async {
    BiblePassage selected = await _repository.getRandomPassage(random: _random);
    for (var attempt = 0; attempt < 4; attempt++) {
      if (_passage == null || selected.reference != _passage!.reference) break;
      selected = await _repository.getRandomPassage(random: _random);
    }
    _passage = selected;
    _error = null;
    final date = _dateString(_dateOnly(_clock()));
    await preferences.setString(_dateKey, date);
    await preferences.setString(_bookKey, selected.reference.bookId);
    await preferences.setInt(_chapterKey, selected.reference.chapter);
    await preferences.setInt(_startKey, selected.reference.startVerse!);
    await preferences.setInt(_endKey, selected.reference.endVerse!);
  }

  Future<BiblePassage?> _loadSavedPassage(SharedPreferences preferences) async {
    final book = preferences.getString(_bookKey);
    final chapter = preferences.getInt(_chapterKey);
    final start = preferences.getInt(_startKey);
    final end = preferences.getInt(_endKey);
    if (book == null || chapter == null || start == null || end == null) {
      return null;
    }
    try {
      final reference = BibleReference(
        bookId: book,
        chapter: chapter,
        startVerse: start,
        endVerse: end,
      );
      final verses = await _repository.getPassage(reference);
      if (verses.isEmpty) return null;
      final books = await _repository.getBooks();
      final matchingBooks = books.where((item) => item.id == book).toList();
      final bookName = matchingBooks.isEmpty
          ? null
          : matchingBooks.first.amharicName;
      return BiblePassage(
        reference: BibleReference(
          bookId: book,
          chapter: chapter,
          startVerse: start,
          endVerse: end,
          label:
              '${bookName ?? book} $chapter:$start${end == start ? '' : '-$end'}',
        ),
        verses: verses,
      );
    } on BibleSourceException {
      return null;
    }
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  String _dateString(DateTime date) => '${date.year}-${date.month}-${date.day}';
}
