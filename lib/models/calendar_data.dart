import 'dart:ui';

enum DayMark { none, fast, feast, today }

class DayInfo {
  final int day;
  final DayMark mark;
  final String? name;
  const DayInfo({required this.day, required this.mark, this.name});
}

class FeastInfo {
  final String eth;
  final String en;
  final String date;
  final String greg;
  final Color color;
  const FeastInfo({
    required this.eth,
    required this.en,
    required this.date,
    required this.greg,
    required this.color,
  });
}
