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
  /// Not `final`: `_initialize()` may swap in a new plugin instance if the
  /// preferred icon is rejected by Android, because the plugin marks itself
  /// initialized *before* the native call and cannot be retried in place.
  static FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _notificationsEnabled = false;
  static Future<void>? _initialization;
  static String? _lastError;
  static int? _launchPrayerIndex;

  /// Whether the Android raw sound resource (`res/raw/a.*`) could be used.
  /// If `false`, notifications are posted without a custom sound so posting
  /// never fails on devices/builds where the resource is missing.
  static bool _customSoundAvailable = true;

  static bool get isInitialized => _initialized;
  static bool get isAvailable => _initialized && _notificationsEnabled;
  static bool get notificationsEnabled => _notificationsEnabled;
  static String? get lastError => _lastError;
  static void Function(int prayerIndex)? onPrayerNotificationTap;

  // Preferred Android notification icon (drawable basename, no extension).
  // The file MUST live at android/app/src/main/res/drawable/notification_icon.png
  // (or notification_icon.xml). It cannot be in a mipmap folder — the plugin
  // only queries the `drawable` resource type.
  static const String _androidIconName = 'notification_icon';

  // Fallbacks tried, in order, if the preferred icon is rejected. Keep this
  // list short and realistic; entries that don't exist just add log noise.
  static const List<String> _androidIconFallbacks = <String>[
    'ic_launcher_rise',
    'ic_launcher',
  ];

  static const String _androidRawSoundName = 'a';
  static const String _iosSoundName = 'a.mp3';

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

  /// Public helper for `main()` so the Android notification *categories*
  /// (channels) exist before the user ever opens Settings.
  static Future<void> ensureChannels() async {
    try {
      await initialize();
    } catch (_) {
      // Never block app startup because of notifications.
    }
  }

  static Future<void> _initialize() async {
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Africa/Addis_Ababa'));

      _lastError = null;

      await _initializePluginWithIconFallback();

      final android = _androidPlugin;

      await _createChannels(android);
      await _readNotificationStatus(android, clearError: false);

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      final launchResponse = launchDetails?.notificationResponse;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchResponse != null) {
        _launchPrayerIndex = _parsePrayerIndex(launchResponse.payload ?? '');
      }

      _initialized = true;
    } catch (error) {
      _initialized = false;
      _notificationsEnabled = false;
      _lastError = 'Notification setup failed: $error';
      rethrow;
    }
  }

  /// Tries [_androidIconName] first, then each of [_androidIconFallbacks].
  /// The first icon Android accepts becomes the active configuration.
  static Future<void> _initializePluginWithIconFallback() async {
    final candidates = <String>[_androidIconName, ..._androidIconFallbacks];
    Object? lastError;

    for (final icon in candidates) {
      final candidate = FlutterLocalNotificationsPlugin();
      try {
        await candidate.initialize(
          InitializationSettings(
            android: AndroidInitializationSettings(icon),
            iOS: const DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
          onDidReceiveNotificationResponse: (response) {
            final index = _parsePrayerIndex(response.payload ?? '');
            if (index != null) onPrayerNotificationTap?.call(index);
          },
        );

        _plugin = candidate;

        if (icon != _androidIconName) {
          _lastError =
              'Notification icon "$_androidIconName" not found; '
              'using "$icon" instead. Add '
              'android/app/src/main/res/drawable/$_androidIconName.png '
              'to restore the custom icon.';
        }
        return;
      } catch (error) {
        lastError = error;
        debugPrint('Notification icon "$icon" rejected: $error');
      }
    }

    throw lastError ?? StateError('No usable notification icon found');
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
          try {
            await android.requestExactAlarmsPermission();
          } catch (_) {
            // Exact alarms are optional; scheduling falls back to inexact.
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
    AndroidFlutterLocalNotificationsPlugin? android, {
    bool clearError = true,
  }) async {
    if (android == null) {
      _notificationsEnabled = true;
    } else {
      _notificationsEnabled = await android.areNotificationsEnabled() ?? false;
    }
    if (clearError && _notificationsEnabled && _initialized) {
      _lastError = null;
    }
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

  /// Override the package name used when opening the system notification
  /// settings screen. Set this in `main()` if your `applicationId` differs
  /// from the default in `android/app/build.gradle`.
  static String androidPackageName = 'com.example.thelot_2';

  static Future<bool> openNotificationSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final intent = AndroidIntent(
        action: 'android.settings.APP_NOTIFICATION_SETTINGS',
        arguments: <String, dynamic>{
          'android.provider.extra.APP_PACKAGE': androidPackageName,
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
    final useCustomSound = soundEnabled && _customSoundAvailable;
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
        sound: useCustomSound
            ? const RawResourceAndroidNotificationSound(_androidRawSoundName)
            : null,
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: 'prayer_reminder',
        presentSound: soundEnabled,
        sound: soundEnabled ? _iosSoundName : null,
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
    await _plugin.cancel(id + 100);
  }

  static Future<void> _createChannels(
    AndroidFlutterLocalNotificationsPlugin? android,
  ) async {
    if (android == null) return;

    final channels = <AndroidNotificationChannel>[
      AndroidNotificationChannel(
        _soundVibrateChannel,
        'Prayer Reminders',
        description: 'Prayer reminders with sound and vibration',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        sound: _customSoundAvailable
            ? const RawResourceAndroidNotificationSound(_androidRawSoundName)
            : null,
      ),
      AndroidNotificationChannel(
        _soundSilentChannel,
        'Prayer Reminders (Sound Only)',
        description: 'Prayer reminders with sound and no vibration',
        importance: Importance.high,
        playSound: true,
        enableVibration: false,
        sound: _customSoundAvailable
            ? const RawResourceAndroidNotificationSound(_androidRawSoundName)
            : null,
      ),
      const AndroidNotificationChannel(
        _silentVibrateChannel,
        'Prayer Reminders (Vibration Only)',
        description: 'Prayer reminders with vibration and no sound',
        importance: Importance.high,
        playSound: false,
        enableVibration: true,
      ),
      const AndroidNotificationChannel(
        _silentChannel,
        'Prayer Reminders (Silent)',
        description: 'Silent prayer reminders',
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
      ),
    ];

    for (final channel in channels) {
      await _createSingleChannel(android, channel);
    }
  }

  static Future<void> _createSingleChannel(
    AndroidFlutterLocalNotificationsPlugin android,
    AndroidNotificationChannel channel,
  ) async {
    try {
      await android.createNotificationChannel(channel);
    } catch (error) {
      if (channel.sound != null) {
        _customSoundAvailable = false;
        try {
          await android.createNotificationChannel(
            AndroidNotificationChannel(
              channel.id,
              channel.name,
              description: channel.description,
              importance: channel.importance,
              playSound: channel.playSound,
              enableVibration: channel.enableVibration,
            ),
          );
          _lastError =
              'Reminder sound resource "$_androidRawSoundName" is missing; '
              'reminders will play the default sound instead.';
          return;
        } catch (_) {
          // Fall through to the generic error below.
        }
      }
      _lastError =
          'Notification channel "${channel.id}" could not be created: $error';
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
