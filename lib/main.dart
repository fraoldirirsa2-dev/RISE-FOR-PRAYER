import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/app/app.dart';
import 'package:rise_for_prayer/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  NotificationService.onPrayerNotificationTap = (index) {
    appNavigatorKey.currentState?.pushNamed(
      '/prayer-session',
      arguments: {'day': DateTime.now().weekday - 1, 'hour': index},
    );
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F172A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await NotificationService.initialize();
  } catch (_) {
    // Notifications are optional; the app must still start if the platform
    // plugin or permission flow is unavailable.
  }

  runApp(const ProviderScope(child: RiseForPrayerApp()));
  // A cold-start notification is received before MaterialApp has a mounted
  // Navigator. Deliver it after the first frame instead of dropping the tap.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final index = NotificationService.consumeLaunchPrayerIndex();
    if (index != null) {
      appNavigatorKey.currentState?.pushNamed(
        '/prayer-session',
        arguments: {'day': DateTime.now().weekday - 1, 'hour': index},
      );
    }
  });
}
