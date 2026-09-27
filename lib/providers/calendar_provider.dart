import 'package:flutter/material.dart';
import 'package:rise_for_prayer/services/time_service.dart';

class CalendarProvider extends ChangeNotifier {
  DateTime _selectedDate = _dateOnly(TimeService.currentNow());
  bool _followsToday = true;

  DateTime get selectedDate => _selectedDate;

  void selectDate(DateTime date) {
    _selectedDate = _dateOnly(date);
    _followsToday = false;
    notifyListeners();
  }

  void selectToday() {
    _selectedDate = _dateOnly(TimeService.currentNow());
    _followsToday = true;
    notifyListeners();
  }

  /// Keeps Today and the selected date synchronized across local midnight
  /// until the user intentionally chooses another date.
  void syncToday(DateTime now) {
    if (!_followsToday) return;
    final today = _dateOnly(now);
    if (isSameDate(_selectedDate, today)) return;
    _selectedDate = today;
    notifyListeners();
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool isSameDate(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  void refreshToday() {
    syncToday(TimeService.currentNow());
  }
}
