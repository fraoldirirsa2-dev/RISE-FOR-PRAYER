import 'package:rise_for_prayer/services/time_service.dart';

class EthiopianObservance {
  const EthiopianObservance({this.feast, this.fast});

  final String? feast;
  final String? fast;

  bool get isFeast => feast != null;
  bool get isFast => fast != null;
}

/// Calendar markers for common fixed Ethiopian Orthodox feasts and the
/// regular Wednesday/Friday fast. Movable feasts and seasonal fasts need a
/// church calendar source and are intentionally not inferred here.
class EthiopianObservanceService {
  const EthiopianObservanceService();

  EthiopianObservance forDate(
    DateTime date,
    TimeService timeService, {
    String language = 'en',
  }) {
    final ethiopian = timeService.toEthiopian(date);
    final feastNames = _fixedFeasts[(ethiopian.month, ethiopian.day)];
    final feast = feastNames == null
        ? null
        : (language == 'eth' ? feastNames.$1 : feastNames.$2);
    final weekday = date.weekday;
    final isWeeklyFast =
        weekday == DateTime.wednesday || weekday == DateTime.friday;
    return EthiopianObservance(
      feast: feast,
      fast: isWeeklyFast
          ? language == 'eth'
                ? (weekday == DateTime.wednesday ? 'ረቡዕ ጾም' : 'ዓርብ ጾም')
                : (weekday == DateTime.wednesday
                      ? 'Wednesday fast'
                      : 'Friday fast')
          : null,
    );
  }

  static const Map<(int, int), (String, String)> _fixedFeasts = {
    (1, 1): ('እንቁጣጣሽ - አዲስ ዓመት', 'Enkutatash - Ethiopian New Year'),
    (1, 17): ('መስቀል - የመስቀሉ በዓል', 'Meskel - Finding of the True Cross'),
    (4, 29): ('ገና - ልደተ ክርስቶስ', 'Gena - Ethiopian Christmas'),
    (5, 11): ('ጥምቀት - ኤጲፋንያ', 'Timkat - Epiphany'),
    (12, 13): ('ደብረ ታቦር - ቡሄ', 'Debre Tabor - Transfiguration'),
  };
}
