import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Owns notification initialization, permission checks, test notifications,
/// and the daily prayer reminder schedule.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _notificationsEnabled = false;
  static Future<void>? _initialization;
  static String? _lastError;
  static int? _launchPrayerIndex;

  static bool get isInitialized => _initialized;
  static bool get isAvailable => _initialized && _notificationsEnabled;
  static bool get notificationsEnabled => _notificationsEnabled;
  static String? get lastError => _lastError;
  static void Function(int prayerIndex)? onPrayerNotificationTap;

  static const String _soundVibrateChannel = 'prayer_reminders_sound_vibrate_a';
  static const String _soundSilentChannel = 'prayer_reminders_sound_silent_a';
  static const String _silentVibrateChannel = 'prayer_reminders_silent_vibrate';
  static const String _silentChannel = 'prayer_reminders_silent';
  static const int _testNotificationId = 9090;

  /// Initialize once. Concurrent calls share the same native initialization.
  static Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initialization ??= _initialize().whenComplete(() {
      _initialization = null;
    });
  }

  static Future<void> _initialize() async {
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Africa/Addis_Ababa'));

      const settings = InitializationSettings(
        // AndroidInitializationSettings expects a drawable resource name,
        // without an @drawable/ prefix. Keep this aligned with the Android
        // notification drawable (also used by older installed builds).
        android: AndroidInitializationSettings('ic_notification_rise_vector'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          final index = _parsePrayerIndex(response.payload ?? '');
          if (index != null) onPrayerNotificationTap?.call(index);
        },
      );

      final android = _androidPlugin;
      await _createChannels(android);
      await _readNotificationStatus(android);

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      final launchResponse = launchDetails?.notificationResponse;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchResponse != null) {
        _launchPrayerIndex = _parsePrayerIndex(launchResponse.payload ?? '');
      }

      _initialized = true;
      _lastError = null;
    } catch (error) {
      _initialized = false;
      _notificationsEnabled = false;
      _lastError = 'Notification setup failed: $error';
      rethrow;
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Returns the prayer index from a notification that launched the app.
  static int? consumeLaunchPrayerIndex() {
    final index = _launchPrayerIndex;
    _launchPrayerIndex = null;
    return index;
  }

  /// Requests notification display access. Exact-alarm access is separate and
  /// only requested when the user enables scheduled reminders.
  static Future<bool> requestPermission({
    bool requestExactAlarms = false,
  }) async {
    if (!await _ensureInitialized()) return false;

    try {
      final android = _androidPlugin;
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        if (granted == false) {
          _lastError = 'Notifications are disabled for this app.';
          await _readNotificationStatus(android);
          return false;
        }
        if (requestExactAlarms) {
          // Exact alarms are optional: reminders fall back to inexact alarms
          // if Android does not grant this special access.
          try {
            await android.requestExactAlarmsPermission();
          } catch (_) {
            // Keep notification permission successful; scheduling handles
            // exact-alarm denial by using an inexact alarm.
          }
        }
      } else {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (ios != null) {
          final granted = await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          if (granted == false) {
            _notificationsEnabled = false;
            _lastError = 'Notifications are disabled for this app.';
            return false;
          }
        }
      }
      return await refreshPermissionStatus();
    } catch (error) {
      _lastError = 'Could not request notification access: $error';
      return false;
    }
  }

  static Future<bool> refreshPermissionStatus() async {
    if (!await _ensureInitialized()) return false;
    try {
      await _readNotificationStatus(_androidPlugin);
      return isAvailable;
    } catch (error) {
      _notificationsEnabled = false;
      _lastError = 'Could not check notification access: $error';
      return false;
    }
  }

  static Future<void> _readNotificationStatus(
    AndroidFlutterLocalNotificationsPlugin? android,
  ) async {
    if (android == null) {
      _notificationsEnabled = true;
    } else {
      _notificationsEnabled = await android.areNotificationsEnabled() ?? false;
    }
    if (_notificationsEnabled && _initialized) _lastError = null;
  }

  static Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      await initialize();
      return _initialized;
    } catch (error) {
      _lastError ??= 'Notification setup failed: $error';
      return false;
    }
  }

  static Future<bool> openNotificationSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      const intent = AndroidIntent(
        action: 'android.settings.APP_NOTIFICATION_SETTINGS',
        arguments: <String, dynamic>{
          'android.provider.extra.APP_PACKAGE': 'com.example.thelot_2',
        },
      );
      await intent.launch();
      return true;
    } catch (error) {
      _lastError = 'Could not open notification settings: $error';
      return false;
    }
  }

  /// Schedules one daily reminder at the next occurrence of the requested
  /// local time. If exact alarms are unavailable, an inexact alarm is used.
  static Future<bool> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    bool vibrationEnabled = true,
    bool soundEnabled = true,
    Duration reminderOffset = Duration.zero,
    String language = 'en',
    int? prayerIndex,
  }) async {
    if (!await _ensureInitialized()) return false;
    if (!await refreshPermissionStatus()) {
      _lastError ??= 'Notifications are disabled for this app.';
      return false;
    }

    try {
      final now = tz.TZDateTime.now(tz.local);
      final prayerTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      var scheduled = prayerTime.subtract(reminderOffset);
      while (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await cancel(id);
      final details = _notificationDetails(
        vibrationEnabled: vibrationEnabled,
        soundEnabled: soundEnabled,
      );
      final payload = prayerIndex == null
          ? null
          : jsonEncode(<String, int>{'prayerId': prayerIndex});

      Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
        id,
        _localize(title, language),
        _localize(body, language),
        scheduled,
        details,
        payload: payload,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      try {
        await schedule(AndroidScheduleMode.exactAllowWhileIdle);
        _lastError = null;
      } on PlatformException {
        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
        _lastError =
            'Reminder scheduled; Android may deliver it a little late.';
      }
      return true;
    } catch (error) {
      _lastError = 'Could not schedule reminder: $error';
      return false;
    }
  }

  /// Sends an immediate notification without touching the daily schedule.
  static Future<bool> showTestNotification({
    required String title,
    required String body,
    required bool vibrationEnabled,
    required bool soundEnabled,
    required String language,
  }) async {
    if (!await _ensureInitialized()) return false;
    if (!await refreshPermissionStatus()) {
      _lastError ??= 'Notifications are disabled for this app.';
      return false;
    }

    try {
      await _plugin.show(
        _testNotificationId,
        _localize(title, language),
        _localize(body, language),
        _notificationDetails(
          vibrationEnabled: vibrationEnabled,
          soundEnabled: soundEnabled,
        ),
      );
      _lastError = null;
      return true;
    } catch (error) {
      _lastError = 'Could not show test notification: $error';
      return false;
    }
  }

  static NotificationDetails _notificationDetails({
    required bool vibrationEnabled,
    required bool soundEnabled,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId(
          soundEnabled: soundEnabled,
          vibrationEnabled: vibrationEnabled,
        ),
        'Prayer Reminders',
        channelDescription: 'Daily prayer hour notifications',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: vibrationEnabled,
        playSound: soundEnabled,
        sound: soundEnabled
            ? const RawResourceAndroidNotificationSound('a')
            : null,
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: 'prayer_reminder',
        presentSound: soundEnabled,
        sound: soundEnabled ? 'a.mp3' : null,
      ),
    );
  }

  static Future<void> cancelAll() async {
    if (await _ensureInitialized()) await _plugin.cancelAll();
  }

  static Future<void> cancelAllPrayerReminders(Iterable<int> ids) async {
    for (final id in ids) {
      await cancel(id);
    }
  }

  static Future<void> cancel(int id) async {
    if (!await _ensureInitialized()) return;
    await _plugin.cancel(id);
    // Cancel the secondary ID used by earlier versions of the app.
    await _plugin.cancel(id + 100);
  }

  static Future<void> _createChannels(
    AndroidFlutterLocalNotificationsPlugin? android,
  ) async {
    if (android == null) return;
    const channels = <AndroidNotificationChannel>[
      AndroidNotificationChannel(
        _soundVibrateChannel,
        'Prayer Reminders',
        description: 'Prayer reminders with sound and vibration',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('a'),
      ),
      AndroidNotificationChannel(
        _soundSilentChannel,
        'Prayer Reminders (Sound Only)',
        description: 'Prayer reminders with sound and no vibration',
        importance: Importance.high,
        playSound: true,
        enableVibration: false,
        sound: RawResourceAndroidNotificationSound('a'),
      ),
      AndroidNotificationChannel(
        _silentVibrateChannel,
        'Prayer Reminders (Vibration Only)',
        description: 'Prayer reminders with vibration and no sound',
        importance: Importance.high,
        playSound: false,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        _silentChannel,
        'Prayer Reminders (Silent)',
        description: 'Silent prayer reminders',
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
      ),
    ];
    for (final channel in channels) {
      await android.createNotificationChannel(channel);
    }
  }

  static String _channelId({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) {
    if (soundEnabled && vibrationEnabled) return _soundVibrateChannel;
    if (soundEnabled) return _soundSilentChannel;
    if (vibrationEnabled) return _silentVibrateChannel;
    return _silentChannel;
  }

  static String _localize(String value, String language) {
    final parts = value.split('|');
    if (parts.length < 2) return value;
    return language == 'en' ? parts.last : parts.first;
  }

  static int? _parsePrayerIndex(String payload) {
    final directIndex = int.tryParse(payload);
    if (directIndex != null) return directIndex;
    try {
      final decoded = jsonDecode(payload);
      final prayerId = decoded is Map<String, dynamic>
          ? decoded['prayerId']
          : null;
      return prayerId is int
          ? prayerId
          : int.tryParse(prayerId?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }
}
