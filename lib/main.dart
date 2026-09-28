import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rise_for_prayer/app/app.dart';
import 'package:rise_for_prayer/services/notification_service.dart';

/// Pushes the prayer-session route for a tapped reminder.
///
/// Shared by both entry points:
///  * [NotificationService.onPrayerNotificationTap] – app already running.
///  * [NotificationService.consumeLaunchPrayerIndex] – app launched cold
///    from a notification.
void _openPrayerSession(int prayerIndex) {
  appNavigatorKey.currentState?.pushNamed(
    '/prayer-session',
    arguments: {'day': DateTime.now().weekday - 1, 'hour': prayerIndex},
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Handle notification taps while the app is already running.
  NotificationService.onPrayerNotificationTap = _openPrayerSession;

  // Android system-bar appearance.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F172A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize notifications before starting the application. This also
  // creates the Android notification channels, so the "Categories" list in
  // Settings → Notifications is populated as soon as the app first launches.
  try {
    await NotificationService.initialize();
  } catch (error) {
    debugPrint('Notification initialization failed: $error');
  }

  runApp(const ProviderScope(child: RiseForPrayerApp()));

  // Run after MaterialApp/Navigator has been mounted.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Ask Android for notification permission.
    try {
      await NotificationService.requestPermission(requestExactAlarms: false);
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
    }

    // Handle a notification that launched the app.
    final index = NotificationService.consumeLaunchPrayerIndex();
    if (index != null) _openPrayerSession(index);
  });
}
