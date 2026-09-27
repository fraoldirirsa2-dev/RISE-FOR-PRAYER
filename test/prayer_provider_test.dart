import 'package:flutter_test/flutter_test.dart';
import 'package:rise_for_prayer/providers/prayer_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('completion keeps individual prayer-hour state', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = PrayerProvider();
    await Future<void>.delayed(Duration.zero);

    provider.toggleHour(3);

    expect(provider.completedCount, 1);
    expect(provider.completedHours[3], isTrue);
    expect(provider.completedHours[0], isFalse);
    expect(provider.nextIncompleteIndex, 0);
    provider.dispose();
  });

  test('progress saved from a previous day is ignored', () async {
    SharedPreferences.setMockInitialValues({
      'prayer_progress': List<String>.filled(7, 'true'),
      'prayer_progress_date': '2000-01-01',
    });
    final provider = PrayerProvider();
    await Future<void>.delayed(Duration.zero);

    expect(provider.completedCount, 0);
    expect(provider.completedHours, everyElement(isFalse));
    provider.dispose();
  });
}
