import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const MethodChannel _androidInfoChannel =
      MethodChannel('rise_for_prayer/android');
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Future<void>? _initialization;
  static bool _available = false;
  static bool? _notificationsEnabled;
  static String? _lastError;
  static int? _launchPrayerIndex;
  static void Function(int prayerIndex)? onPrayerNotificationTap;

  static bool get isAvailable => _available;
  static String? get lastError => _lastError;
  static bool? get notificationsEnabled => _notificationsEnabled;

  static const _soundVibrateChannel = 'prayer_reminders_sound_vibrate_a';
  static const _soundSilentChannel = 'prayer_reminders_sound_silent_a';
  static const _silentVibrateChannel = 'prayer_reminders_silent_vibrate';
  static const _silentChannel = 'prayer_reminders_silent';
  static const _testNotificationId = 9090;

  /// Initialises the native notification layer once. Concurrent callers share
  /// the same operation; this is important because providers may be restored
  /// while the app is still booting.
  static Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final existingInitialization = _initialization;
    if (existingInitialization != null) return existingInitialization;

    final initialization = _initialize();
    _initialization = initialization;
    return initialization.whenComplete(() {
      // Do not permanently cache a failed platform initialization. A later
      // retry can succeed after the app regains a valid plugin host.
      if (!_initialized) _initialization = null;
    });
  }

  static Future<void> _initialize() async {
    tz_data.initializeTimeZones();

    try {
      tz.setLocalLocation(tz.getLocation('Africa/Addis_Ababa'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification_rise');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          // Ask only after an explicit user action in Settings. An automatic
          // prompt at launch has poor opt-in rates and cannot be retried well.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        final index = payload == null ? null : _parsePrayerIndex(payload);
        if (index != null) onPrayerNotificationTap?.call(index);
      },
    );

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await _createChannels(androidImplementation);
    await _readPermissionStatus(androidImplementation);
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      final index = _parsePrayerIndex(launchResponse.payload ?? '');
      _launchPrayerIndex = index;
    }
    _initialized = true;
    _available = _notificationsEnabled == true;
    _lastError = null;
  }

  /// Returns a notification route target captured when a notification cold
  /// started the app. It is consumed once the Navigator is mounted.
  static int? consumeLaunchPrayerIndex() {
    final index = _launchPrayerIndex;
    _launchPrayerIndex = null;
    return index;
  }

  static Future<bool> requestPermission() async {
    await ensureInitialized();
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      final sdkInt = await _androidSdkInt();
      if (sdkInt >= 33) {
        final granted = await androidImplementation.requestNotificationsPermission();
        if (granted == false) {
          await refreshPermissionStatus();
          _lastError = 'Prayer reminders are disabled because notification permission is off.';
          return false;
        }
      }
      if (sdkInt >= 31) {
        await androidImplementation.requestExactAlarmsPermission();
      }
    } else {
      final iosImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosImplementation != null) {
        final granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        if (granted == false) {
          _notificationsEnabled = false;
          _available = false;
          _lastError = 'Prayer reminders are disabled because notification permission is off.';
          return false;
        }
      }
    }
    return refreshPermissionStatus();
  }

  static Future<int> _androidSdkInt() async {
    try {
      return await _androidInfoChannel.invokeMethod<int>('sdkInt') ?? 0;
    } on MissingPluginException {
      return 0;
    } on PlatformException {
      return 0;
    }
  }

  static Future<bool> refreshPermissionStatus() async {
    await ensureInitialized();
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await _readPermissionStatus(androidImplementation);
    return _available;
  }

  static Future<void> _readPermissionStatus(
    AndroidFlutterLocalNotificationsPlugin? android,
  ) async {
    try {
      _notificationsEnabled = android == null
          ? true
          : (await android.areNotificationsEnabled() ?? true);
    } on MissingPluginException {
      // Desktop/test hosts do not implement Android notification APIs.
      _notificationsEnabled = true;
    }
    _available = _notificationsEnabled == true;
    if (_available) _lastError = null;
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
    } on Object {
      return false;
    }
  }

  static Future<void> ensureInitialized() async {
    if (!_initialized) {
      try {
        await initialize();
      } catch (error) {
        _initialized = false;
        _available = false;
        _lastError = error.toString();
      }
    }
  }

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
    await ensureInitialized();
    await refreshPermissionStatus();
    if (!_initialized || !_available) {
      _lastError ??= 'Notification permission is unavailable.';
      return false;
    }
    _lastError = null;

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

    await _plugin.cancel(id);
    await _plugin.cancel(id + 100);
    final channelId = _channelId(
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );
    final localizedTitle = _localize(title, language);
    final localizedBody = _localize(body, language);
    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Prayer Reminders',
      channelDescription: 'Daily prayer hour notifications',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: vibrationEnabled,
      playSound: soundEnabled,
      sound: soundEnabled
          ? const RawResourceAndroidNotificationSound('a')
          : null,
    );
    final iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'prayer_reminder',
      presentSound: soundEnabled,
      sound: soundEnabled ? 'a.mp3' : null,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id,
      localizedTitle,
      localizedBody,
      scheduled,
      details,
      payload: prayerIndex == null
          ? null
          : jsonEncode(<String, int>{'prayerId': prayerIndex}),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: mode,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      // Exact alarms can be declined in Android settings. Keep the reminder
      // alive rather than failing silently; Android may deliver it slightly
      // late when the device is idle.
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
      _lastError =
          'Exact alarms are unavailable; reminders may arrive a little late.';
    }
    return true;
  }

  /// Delivers an immediate local notification from the Settings screen.
  /// It deliberately uses a dedicated ID so testing never replaces one of the
  /// seven scheduled canonical-hour reminders.
  static Future<bool> showTestNotification({
    required String title,
    required String body,
    required bool vibrationEnabled,
    required bool soundEnabled,
    required String language,
  }) async {
    await ensureInitialized();
    await refreshPermissionStatus();
    if (!_initialized || !_available) {
      _lastError ??= 'Notification permission is unavailable.';
      return false;
    }

    final channelId = _channelId(
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
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

    try {
      await _plugin.show(
        _testNotificationId,
        _localize(title, language),
        _localize(body, language),
        details,
      );
      _lastError = null;
      return true;
    } on PlatformException catch (error) {
      _lastError = error.message ?? 'Unable to show a test notification.';
      return false;
    } on MissingPluginException {
      _lastError = 'Test notifications are available on a supported device.';
      return false;
    }
  }

  static Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  static Future<void> cancelAllPrayerReminders(Iterable<int> ids) async {
    for (final id in ids) {
      await cancel(id);
    }
  }

  static Future<void> cancel(int id) async {
    if (!_initialized) return;
    await _plugin.cancel(id);
    await _plugin.cancel(id + 100);
  }

  static Future<void> _createChannels(
    AndroidFlutterLocalNotificationsPlugin? android,
  ) async {
    if (android == null) return;
    const channels = [
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
    if (parts.length < 2) {
      return value;
    }
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
    } on Object {
      return null;
    }
  }
}
