import 'package:flutter_test/flutter_test.dart';
import 'package:rise_for_prayer/data/prayer_data.dart';
import 'package:rise_for_prayer/services/time_service.dart';
import 'package:rise_for_prayer/providers/calendar_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'converts Ethiopian New Year and round-trips the same Gregorian day',
    () {
      final service = TimeService();

      final ethiopianNewYear = service.toEthiopian(DateTime(2025, 9, 11));
      expect(
        ethiopianNewYear,
        const EthiopianDate(year: 2018, month: 1, day: 1),
      );

      final roundTrip = service.toGregorian(
        const EthiopianDate(year: 2018, month: 1, day: 1),
      );
      expect(roundTrip, DateTime(2025, 9, 11));

      service.dispose();
    },
  );

  test('keeps a date on the Ethiopian calendar boundary consistent across the month switch', () {
    final service = TimeService();

    final firstOfMonth = service.toEthiopian(DateTime(2025, 9, 11));
    final secondOfMonth = service.toEthiopian(DateTime(2025, 9, 12));

    expect(firstOfMonth.month, 1);
    expect(firstOfMonth.day, 1);
    expect(secondOfMonth.month, 1);
    expect(secondOfMonth.day, 2);

    service.dispose();
  });

  test('handles Ethiopian leap-year Pagumen and New Year boundaries', () {
    final service = TimeService();

    expect(
      service.toEthiopian(DateTime(2023, 9, 12)),
      const EthiopianDate(year: 2016, month: 1, day: 1),
    );
    expect(
      service.toEthiopian(DateTime(2024, 9, 10)),
      const EthiopianDate(year: 2016, month: 13, day: 5),
    );
    expect(
      service.toGregorian(const EthiopianDate(year: 2016, month: 13, day: 6)),
      DateTime(2024, 9, 11),
    );
    expect(
      service.toEthiopian(DateTime(2024, 9, 11)),
      const EthiopianDate(year: 2017, month: 1, day: 1),
    );

    service.dispose();
  });

  test('next prayer countdown is never negative', () {
    final service = TimeService();
    final countdown = service.nextPrayerCountdown;

    expect(
      service.nextPrayer.remainingFrom(service.now),
      isNot(lessThan(Duration.zero)),
    );
    expect(countdown.split(':'), hasLength(3));
    service.dispose();
  });

  test('current prayer is always a known canonical hour', () {
    final service = TimeService();

    expect(hours.contains(service.currentPrayer.hour), isTrue);
    service.dispose();
  });

  test('CalendarProvider keeps a canonical selected date', () {
    final provider = CalendarProvider();
    final selected = DateTime(2024, 2, 29, 23, 45);

    provider.selectDate(selected);

    expect(provider.selectedDate, DateTime(2024, 2, 29));
    provider.selectToday();
    expect(
      CalendarProvider.isSameDate(
        provider.selectedDate,
        TimeService.currentNow(),
      ),
      isTrue,
    );
    provider.dispose();
  });
}
