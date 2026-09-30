import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rise_for_prayer/app/app.dart';
import 'package:rise_for_prayer/services/notification_service.dart';

void _openPrayerSession(int prayerIndex) {
  final navigator = appNavigatorKey.currentState;

  if (navigator == null) {
    debugPrint('Prayer navigation skipped: Navigator is not ready.');
    return;
  }

  navigator.pushNamed(
    '/prayer-session',
    arguments: {'day': DateTime.now().weekday - 1, 'hour': prayerIndex},
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  NotificationService.onPrayerNotificationTap = _openPrayerSession;

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

    debugPrint('NotificationService initialized.');
  } catch (error, stackTrace) {
    debugPrint('Notification initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const ProviderScope(child: RiseForPrayerApp()));

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final enabled = await NotificationService.requestPermissions(
        requestExactAlarms: false,
      );

      debugPrint('Notification permission: $enabled');

      final current =
          await NotificationService.refreshNotificationPermissionStatus();

      debugPrint('Notifications currently enabled: $current');
    } catch (error, stackTrace) {
      debugPrint('Notification permission request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    final launchIndex = NotificationService.consumeLaunchPrayerIndex();

    if (launchIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPrayerSession(launchIndex);
      });
    }
  });
}
