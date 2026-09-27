import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:rise_for_prayer/data/prayer_data.dart';
import 'package:rise_for_prayer/features/prayer_hours/data/canonical_prayer_hours.dart';
import 'package:rise_for_prayer/features/prayer_hours/domain/prayer_schedule.dart';
import 'package:rise_for_prayer/models/hour_data.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class EthiopianDate {
  const EthiopianDate({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;

  @override
  bool operator ==(Object other) =>
      other is EthiopianDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

class PrayerEvent {
  const PrayerEvent({required this.hour, required this.dateTime});

  final HourData hour;
  final DateTime dateTime;

  Duration remainingFrom(DateTime now) {
    final remaining = dateTime.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class TimeService extends ChangeNotifier {
  static const _prayerSchedule = PrayerSchedule(canonicalPrayerHours);
  TimeService({DateTime Function()? clock}) : _clock = clock ?? currentNow {
    _initializeTimezone();
    _now = getCurrentGregorianDateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _now = getCurrentGregorianDateTime();
      notifyListeners();
    });
  }

  static DateTime currentNow() {
    _ensureTimezone();
    return tz.TZDateTime.now(tz.local);
  }

  late DateTime _now;
  final DateTime Function() _clock;
  Timer? _timer;

  DateTime get now => _now;
  String get formattedTime => DateFormat('h:mm:ss a').format(_now);
  String get formattedGregorianDate =>
      DateFormat('EEEE, MMMM d, yyyy').format(_now);
  String formatGregorianDate(DateTime date) =>
      DateFormat('EEEE, MMMM d, yyyy').format(date);
  EthiopianDate get ethiopianDate => toEthiopian(_now);

  PrayerEvent get nextPrayer {
    final scheduled = _prayerSchedule.next(_now);
    return _toPrayerEvent(scheduled);
  }

  PrayerEvent get currentPrayer {
    final scheduled = _prayerSchedule.current(_now);
    return _toPrayerEvent(scheduled);
  }

  String get nextPrayerCountdown {
    final duration = nextPrayer.remainingFrom(_now);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  DateTime getCurrentGregorianDateTime() => getCurrentTime();
  DateTime getCurrentTime() => _clock();
  EthiopianDate getCurrentEthiopianDate() => toEthiopian(getCurrentTime());
  int getCurrentHour() => getCurrentTime().hour;
  int getCurrentMinute() => getCurrentTime().minute;
  int getCurrentSecond() => getCurrentTime().second;

  DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime monthStart(DateTime date) => DateTime(date.year, date.month);

  int daysInGregorianMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  int daysInEthiopianMonth(EthiopianDate date) {
    if (date.month != 13) return 30;
    return _isEthiopianLeapYear(date.year) ? 6 : 5;
  }

  DateTime shiftGregorianMonth(DateTime date, int offset) {
    final target = DateTime(date.year, date.month + offset, 1);
    final day = date.day.clamp(
      1,
      daysInGregorianMonth(target.year, target.month),
    );
    return DateTime(target.year, target.month, day);
  }

  DateTime shiftEthiopianMonth(DateTime date, int offset) {
    final current = toEthiopian(date);
    final absoluteMonth = current.year * 13 + current.month - 1 + offset;
    final year = absoluteMonth ~/ 13;
    final month = absoluteMonth % 13 + 1;
    final day = current.day.clamp(
      1,
      daysInEthiopianMonth(EthiopianDate(year: year, month: month, day: 1)),
    );
    return toGregorian(EthiopianDate(year: year, month: month, day: day));
  }

  DateTime shiftYear(DateTime date, int offset) {
    final target = DateTime(date.year + offset, date.month, 1);
    final day = date.day.clamp(
      1,
      daysInGregorianMonth(target.year, target.month),
    );
    return DateTime(target.year, target.month, day);
  }

  String formatEthiopianDateFor(DateTime date, {String language = 'eth'}) {
    final ethiopian = toEthiopian(date);
    final months = language == 'eth' ? ethMonths : ethMonthsEnglish;
    final era = language == 'eth' ? 'ዓ.ም' : 'E.C.';
    return '${months[ethiopian.month - 1]} ${ethiopian.day}, '
        '${ethiopian.year} $era';
  }

  PrayerStatus prayerStatus(PrayerOccurrence occurrence, DateTime now) =>
      _prayerSchedule.statusFor(occurrence, now);

  List<PrayerOccurrence> prayerOccurrencesFor(DateTime date) =>
      _prayerSchedule.occurrencesForDate(date);

  EthiopianDate toEthiopian(DateTime date) {
    final normalizedDate = _dateOnly(date);
    final currentYearStart = _currentEthiopianYearStart(normalizedDate);
    final ethiopianYear = currentYearStart.year - 7;
    final dayOfYear = normalizedDate.difference(currentYearStart).inDays + 1;
    return EthiopianDate(
      year: ethiopianYear,
      month: ((dayOfYear - 1) ~/ 30) + 1,
      day: ((dayOfYear - 1) % 30) + 1,
    );
  }

  DateTime toGregorian(EthiopianDate date) {
    if (date.month < 1 || date.month > 13 || date.day < 1) {
      throw ArgumentError('Invalid Ethiopian date');
    }
    final daysInMonth = date.month == 13
        ? (_isEthiopianLeapYear(date.year) ? 6 : 5)
        : 30;
    if (date.day > daysInMonth) {
      throw ArgumentError('Invalid Ethiopian date');
    }
    final yearStart = DateTime(
      date.year + 7,
      9,
      _isEthiopianLeapYear(date.year) ? 12 : 11,
    );
    return yearStart.add(
      Duration(days: ((date.month - 1) * 30) + (date.day - 1)),
    );
  }

  String formatEthiopianDate({String language = 'eth'}) {
    return formatEthiopianDateFor(_now, language: language);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initializeTimezone() => _ensureTimezone();

  static void _ensureTimezone() {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Africa/Addis_Ababa'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  PrayerEvent _toPrayerEvent(ScheduledPrayerHour scheduled) => PrayerEvent(
    hour: hours.firstWhere(
      (hour) => hour.id == scheduled.prayerHour.readerIndex,
    ),
    // The domain schedule is intentionally platform-independent. Rehydrate
    // it in the app's configured timezone before calculating a countdown.
    dateTime: tz.TZDateTime(
      tz.local,
      scheduled.at.year,
      scheduled.at.month,
      scheduled.at.day,
      scheduled.at.hour,
      scheduled.at.minute,
    ),
  );

  DateTime _currentEthiopianYearStart(DateTime date) {
    final thisYearStart = DateTime(
      date.year,
      9,
      _isEthiopianLeapYear(date.year - 7) ? 12 : 11,
    );
    if (!date.isBefore(thisYearStart)) {
      return thisYearStart;
    }
    final previousYearStart = DateTime(
      date.year - 1,
      9,
      _isEthiopianLeapYear(date.year - 8) ? 12 : 11,
    );
    return previousYearStart;
  }

  bool _isEthiopianLeapYear(int ethiopianYear) => ethiopianYear % 4 == 0;

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
