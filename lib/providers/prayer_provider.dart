import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rise_for_prayer/services/preferences_store.dart';
import 'package:rise_for_prayer/services/time_service.dart';

class PrayerProvider extends ChangeNotifier {
  List<bool> _completedHours = List.filled(7, false);
  final Map<String, List<bool>> _history = {};
  Timer? _dayTimer;
  late String _activeDate;

  PrayerProvider() {
    _activeDate = _dateKey(TimeService.currentNow());
    unawaited(_loadProgress());
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final currentDate = _dateKey(TimeService.currentNow());
      if (currentDate == _activeDate) return;
      _activeDate = currentDate;
      _completedHours = List.filled(7, false);
      _recordToday();
      _saveProgress();
      notifyListeners();
    });
  }

  List<bool> get completedHours => List.unmodifiable(_completedHours);
  Map<String, List<bool>> get history => {
    for (final entry in _history.entries)
      entry.key: List<bool>.unmodifiable(entry.value),
  };
  int get completedCount => _completedHours.where((e) => e).length;

  int get nextIncompleteIndex {
    for (int i = 0; i < _completedHours.length; i++) {
      if (!_completedHours[i]) return i;
    }
    return 0;
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    super.dispose();
  }

  void toggleHour(int index) {
    if (index < 0 || index >= _completedHours.length) return;
    _completedHours[index] = !_completedHours[index];
    _recordToday();
    unawaited(_saveProgress());
    notifyListeners();
  }

  void setHourCompleted(int index, bool value) {
    if (index < 0 || index >= _completedHours.length) return;
    _completedHours[index] = value;
    _recordToday();
    unawaited(_saveProgress());
    notifyListeners();
  }

  void resetAll() {
    _completedHours = List.filled(7, false);
    _recordToday();
    unawaited(_saveProgress());
    notifyListeners();
  }

  Future<void> _saveProgress() async {
    final prefs = await PreferencesStore.instance.preferences;
    await prefs.setStringList(
      'prayer_progress',
      _completedHours.map((e) => e.toString()).toList(),
    );
    await prefs.setString(
      'prayer_progress_date',
      _dateKey(TimeService.currentNow()),
    );
    await prefs.setString('prayer_history', jsonEncode(_history));
  }

  Future<void> _loadProgress() async {
    final prefs = await PreferencesStore.instance.preferences;
    final savedHistory = prefs.getString('prayer_history');
    if (savedHistory != null) {
      try {
        final decoded = jsonDecode(savedHistory) as Map<String, dynamic>;
        _history.addAll(
          decoded.map(
            (key, value) => MapEntry(
              key,
              (value as List<dynamic>).map((item) => item == true).toList(),
            ),
          ),
        );
      } catch (_) {
        _history.clear();
      }
    }
    final data = prefs.getStringList('prayer_progress');
    final savedDate = prefs.getString('prayer_progress_date');
    final today = TimeService.currentNow();
    if (data != null && data.length == 7 && savedDate == _dateKey(today)) {
      _completedHours = data.map((e) => e == 'true').toList();
    }
    _recordToday();
    _activeDate = _dateKey(today);
    notifyListeners();
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void _recordToday() {
    _history[_dateKey(TimeService.currentNow())] = List<bool>.from(
      _completedHours,
    );
  }
}
