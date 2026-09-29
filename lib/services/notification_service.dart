import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Rise for Prayer notification service.
///
/// Android resources:
///
///   android/app/src/main/res/drawable/notification_icon.png
///   android/app/src/main/res/raw/a.mp3
class NotificationService {
  NotificationService._();

  // ---------------------------------------------------------------------------
  // Plugin state
  // ---------------------------------------------------------------------------

  static FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static Future<void>? _initialization;
  static bool _notificationsEnabled = false;
  static String? _lastError;
  static int? _launchPrayerIndex;
  static bool _customSoundAvailable = true;

  /// Called when a prayer notification is tapped while the app is running.
  /// Set from `main()` before `runApp`.
  static void Function(int prayerIndex)? onPrayerNotificationTap;

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  static const String androidPackageName = 'com.example.thelot_2';

  static const String _androidIconName = 'notification_icon';
  static const String _androidRawSoundName = 'a';
  static const String _iosSoundName = 'a.mp3';
  static const String _timezoneName = 'Africa/Addis_Ababa';

  static const String _channelSoundVibrate = 'prayer_reminders_sound_vibrate_a';
  static const String _channelSoundSilent = 'prayer_reminders_sound_silent_a';
  static const String _channelSilentVibrate = 'prayer_reminders_silent_vibrate';
  static const String _channelSilent = 'prayer_reminders_silent';

  static const int _testNotificationId = 9090;

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  static bool get initialized => _initialized;
  static bool get notificationsEnabled => _notificationsEnabled;
  static bool get isAvailable => _initialized && _notificationsEnabled;
  static String? get lastError => _lastError;
  static int? get launchPrayerIndex => _launchPrayerIndex;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  static Future<void> initialize() async {
    if (_initialized) {
      await refreshNotificationPermissionStatus();
      return;
    }

    _initialization ??= _initializeInternal();

    try {
      await _initialization;
    } finally {
      _initialization = null;
    }
  }

  static Future<void> _initializeInternal() async {
    try {
      tz_data.initializeTimeZones();

      try {
        tz.setLocalLocation(tz.getLocation(_timezoneName));
      } catch (error) {
        debugPrint('Could not set timezone $_timezoneName: $error');
      }

      _lastError = null;

      final candidate = FlutterLocalNotificationsPlugin();

      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings(_androidIconName),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      final initialized = await candidate.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      if (initialized != true) {
        _lastError = 'Flutter Local Notifications initialization failed.';
        debugPrint(_lastError);
        return;
      }

      _plugin = candidate;
      _initialized = true;

      await _createNotificationChannels();
      await refreshNotificationPermissionStatus();

      debugPrint(
        'NotificationService initialized. '
        'notificationsEnabled=$_notificationsEnabled',
      );
    } catch (error, stackTrace) {
      _initialized = false;
      _lastError = error.toString();

      debugPrint('NotificationService initialization error: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  static Future<bool> refreshNotificationPermissionStatus() async {
    if (kIsWeb) {
      _notificationsEnabled = true;
      return true;
    }

    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (android != null) {
        final enabled = await android.areNotificationsEnabled();
        _notificationsEnabled = enabled ?? false;
        return _notificationsEnabled;
      }

      return _notificationsEnabled;
    } catch (error) {
      debugPrint('Could not check notification permission: $error');
      return _notificationsEnabled;
    }
  }

  static Future<bool> requestPermissions() async {
    await initialize();

    if (kIsWeb) {
      _notificationsEnabled = true;
      return true;
    }

    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (android != null) {
        final result = await android.requestNotificationsPermission();
        _notificationsEnabled = result ?? false;
        return _notificationsEnabled;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      if (ios != null) {
        final result = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _notificationsEnabled = result ?? false;
        return _notificationsEnabled;
      }

      return false;
    } catch (error, stackTrace) {
      _lastError = error.toString();
      debugPrint('Notification permission request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> initializeAndRequestPermissions() async {
    await initialize();
    final enabled = await refreshNotificationPermissionStatus();
    if (enabled) return true;
    return requestPermissions();
  }

  static Future<bool> requestExactAlarmPermission() async {
    if (kIsWeb) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return false;
      final result = await android.requestExactAlarmsPermission();
      return result ?? false;
    } catch (error) {
      debugPrint('Exact alarm permission request failed: $error');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Channels
  // ---------------------------------------------------------------------------

  static Future<void> _createNotificationChannels() async {
    if (kIsWeb) return;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) return;

    final sound = _customSoundAvailable
        ? const RawResourceAndroidNotificationSound(_androidRawSoundName)
        : null;

    final channels = <AndroidNotificationChannel>[
      AndroidNotificationChannel(
        _channelSoundVibrate,
        'Prayer reminders',
        description: 'Prayer reminders with sound and vibration.',
        importance: Importance.max,
        playSound: true,
        sound: sound,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        _channelSoundSilent,
        'Prayer reminders - sound only',
        description: 'Prayer reminders with sound and without vibration.',
        importance: Importance.max,
        playSound: true,
        sound: sound,
        enableVibration: false,
      ),
      const AndroidNotificationChannel(
        _channelSilentVibrate,
        'Prayer reminders - vibration',
        description: 'Prayer reminders with vibration and no sound.',
        importance: Importance.max,
        playSound: false,
        enableVibration: true,
      ),
      const AndroidNotificationChannel(
        _channelSilent,
        'Prayer reminders - silent',
        description: 'Prayer reminders without sound or vibration.',
        importance: Importance.max,
        playSound: false,
        enableVibration: false,
      ),
    ];

    for (final channel in channels) {
      await _createChannelSafely(android, channel);
    }
  }

  static Future<void> _createChannelSafely(
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
          _lastError = 'Custom reminder sound is unavailable. Using the default Android sound.';
          return;
        } catch (retryError) {
          debugPrint('Channel retry failed: $retryError');
        }
      }

      _lastError =
          'Notification channel "${channel.id}" could not be created: $error';
      debugPrint(_lastError);
    }
  }

  // ---------------------------------------------------------------------------
  // Test notification
  // ---------------------------------------------------------------------------

  static Future<bool> showTestNotification({
    String? title,
    String? body,
    bool soundEnabled = true,
    bool vibrationEnabled = true,
    String language = 'en',
  }) async {
    await initialize();
    await refreshNotificationPermissionStatus();

    if (!_notificationsEnabled) {
      final granted = await requestPermissions();
      if (!granted) {
        _lastError = 'Notifications are disabled for this app.';
        return false;
      }
    }

    try {
      await _plugin.show(
        _testNotificationId,
        title != null ? _localize(title, language) : 'ለጸሎት ተነሱ',
        body != null ? _localize(body, language) : 'የማሳወቂያ ሙከራ',
        _notificationDetails(
          soundEnabled: soundEnabled,
          vibrationEnabled: vibrationEnabled,
        ),
        payload: jsonEncode({'prayerId': 0}),
      );

      _lastError = null;
      debugPrint('Test notification displayed successfully.');
      return true;
    } catch (error) {
      _lastError = 'Could not show test notification: $error';
      debugPrint(_lastError);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Schedule one prayer reminder
  // ---------------------------------------------------------------------------

  static Future<void> schedulePrayerReminder({
    required int prayerIndex,
    required DateTime prayerTime,
    int reminderMinutes = 0,
    bool soundEnabled = true,
    bool vibrationEnabled = true,
    String? title,
    String? body,
  }) async {
    await initialize();
    await refreshNotificationPermissionStatus();

    if (!_notificationsEnabled) {
      debugPrint('Skipping schedule: notification permission not granted.');
      return;
    }

    if (prayerIndex < 0) {
      throw ArgumentError.value(
        prayerIndex,
        'prayerIndex',
        'Prayer index cannot be negative.',
      );
    }

    if (reminderMinutes < 0 || reminderMinutes > 15) {
      throw ArgumentError.value(
        reminderMinutes,
        'reminderMinutes',
        'Reminder must be between 0 and 15 minutes.',
      );
    }

    final reminderTime = prayerTime.subtract(
      Duration(minutes: reminderMinutes),
    );

    final location = tz.local;
    final scheduled = tz.TZDateTime.from(reminderTime, location);
    final now = tz.TZDateTime.now(location);

    if (scheduled.isBefore(now)) {
      debugPrint('Skipping past notification: $scheduled');
      return;
    }

    final id = notificationId(
      prayerIndex: prayerIndex,
      reminderMinutes: reminderMinutes,
    );

    final details = _notificationDetails(
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );

    final notificationTitle = title ?? _defaultTitle(prayerIndex);
    final notificationBody = body ?? _defaultBody(prayerIndex, reminderMinutes);

    final payload = jsonEncode({
      'prayerId': prayerIndex,
      'reminderMinutes': reminderMinutes,
    });

    await _zonedScheduleWithFallback(
      id: id,
      title: notificationTitle,
      body: notificationBody,
      scheduled: scheduled,
      details: details,
      payload: payload,
    );
  }

  static Future<void> scheduleAllPrayerReminders({
    required List<DateTime> prayerTimes,
    int reminderMinutes = 0,
    bool soundEnabled = true,
    bool vibrationEnabled = true,
  }) async {
    await initialize();
    await refreshNotificationPermissionStatus();

    if (!_notificationsEnabled) {
      debugPrint('Cannot schedule reminders: notifications disabled.');
      return;
    }

    await cancelAllPrayerNotifications();

    for (var index = 0; index < prayerTimes.length; index++) {
      await schedulePrayerReminder(
        prayerIndex: index,
        prayerTime: prayerTimes[index],
        reminderMinutes: reminderMinutes,
        soundEnabled: soundEnabled,
        vibrationEnabled: vibrationEnabled,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Cancellation
  // ---------------------------------------------------------------------------

  static Future<void> cancelPrayerReminder({
    required int prayerIndex,
    required int reminderMinutes,
  }) async {
    await initialize();
    await _plugin.cancel(
      notificationId(
        prayerIndex: prayerIndex,
        reminderMinutes: reminderMinutes,
      ),
    );
  }

  static Future<void> cancelAllPrayerNotifications() async {
    await initialize();
    for (var prayerIndex = 0; prayerIndex < 7; prayerIndex++) {
      for (final reminderMinutes in const [0, 5, 10, 15]) {
        await _plugin.cancel(
          notificationId(
            prayerIndex: prayerIndex,
            reminderMinutes: reminderMinutes,
          ),
        );
      }
    }
  }

  static Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  static int notificationId({
    required int prayerIndex,
    required int reminderMinutes,
  }) {
    return 1000 + (prayerIndex * 100) + reminderMinutes;
  }

  // ---------------------------------------------------------------------------
  // Notification details
  // ---------------------------------------------------------------------------

  static NotificationDetails _notificationDetails({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) {
    final channelId = _channelId(
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );

    final useCustomSound = soundEnabled && _customSoundAvailable;

    final android = AndroidNotificationDetails(
      channelId,
      _channelName(channelId),
      channelDescription: 'Notifications for Ethiopian Orthodox prayer hours.',
      importance: Importance.max,
      priority: Priority.high,
      icon: _androidIconName,
      playSound: soundEnabled,
      enableVibration: vibrationEnabled,
      sound: useCustomSound
          ? const RawResourceAndroidNotificationSound(_androidRawSoundName)
          : null,
      ticker: 'ለጸሎት ተነሱ',
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    final ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: soundEnabled,
      sound: soundEnabled ? _iosSoundName : null,
    );

    return NotificationDetails(android: android, iOS: ios);
  }

  static String _channelId({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) {
    if (soundEnabled && vibrationEnabled) return _channelSoundVibrate;
    if (soundEnabled && !vibrationEnabled) return _channelSoundSilent;
    if (!soundEnabled && vibrationEnabled) return _channelSilentVibrate;
    return _channelSilent;
  }

  static String _channelName(String channelId) {
    switch (channelId) {
      case _channelSoundVibrate:
        return 'Prayer reminders';
      case _channelSoundSilent:
        return 'Prayer reminders - sound only';
      case _channelSilentVibrate:
        return 'Prayer reminders - vibration';
      case _channelSilent:
        return 'Prayer reminders - silent';
      default:
        return 'Prayer reminders';
    }
  }

  // ---------------------------------------------------------------------------
  // Internal scheduling helper
  // ---------------------------------------------------------------------------

  static Future<void> _zonedScheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduled,
    required NotificationDetails details,
    required String payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      _lastError = null;
    } catch (error) {
      debugPrint('Exact scheduling failed: $error');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduled,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
        _lastError =
            'Reminder scheduled; Android may deliver it a little late.';
      } catch (fallbackError) {
        _lastError = fallbackError.toString();
        debugPrint('Fallback scheduling failed: $fallbackError');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Default text
  // ---------------------------------------------------------------------------

  static String _defaultTitle(int prayerIndex) {
    const titles = <String>[
      'ነግህ 12 • Midnight Prayer',
      'ሠለስት 3 • Morning Prayer',
      'ቀትር 6 • Third Hour Prayer',
      'ተሰዓት 9 • Sixth Hour Prayer',
      'ሠርክ 12 • Ninth Hour Prayer',
      'ንዋም 3 • Vespers',
      'መንፈቀ ሌሊት 6 • Compline',
    ];
    if (prayerIndex >= 0 && prayerIndex < titles.length) {
      return titles[prayerIndex];
    }
    return 'ለጸሎት ተነሱ • Rise for Prayer';
  }

  static String _defaultBody(int prayerIndex, int reminderMinutes) {
    if (reminderMinutes == 0) return 'የጸሎት ሰዓት ደርሷል።';
    return 'የጸሎት ሰዓት ከ$reminderMinutes ደቂቃ በኋላ ነው።';
  }

  static String _localize(String value, String language) {
    final parts = value.split('|');
    if (parts.length < 2) return value;
    return language.toLowerCase() == 'en'
        ? parts.last.trim()
        : parts.first.trim();
  }

  // ---------------------------------------------------------------------------
  // Notification tap handling
  // ---------------------------------------------------------------------------

  static void _onNotificationResponse(NotificationResponse response) {
    _handleNotificationPayload(response.payload);
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    _handleNotificationPayload(response.payload);
  }

  static void _handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final prayerId = decoded['prayerId'];
        if (prayerId is int) {
          _launchPrayerIndex = prayerId;
        } else if (prayerId is String) {
          _launchPrayerIndex = int.tryParse(prayerId);
        }
      } else {
        _launchPrayerIndex = int.tryParse(payload);
      }
    } catch (_) {
      _launchPrayerIndex = int.tryParse(payload);
    }

    debugPrint('Notification tapped. prayerIndex=$_launchPrayerIndex');

    // Notify the app so it can navigate if the app is already running.
    final index = _launchPrayerIndex;
    if (index != null) {
      onPrayerNotificationTap?.call(index);
    }
  }

  static int? takeLaunchPrayerIndex() {
    final value = _launchPrayerIndex;
    _launchPrayerIndex = null;
    return value;
  }

  /// Legacy alias for [takeLaunchPrayerIndex].
  static int? consumeLaunchPrayerIndex() => takeLaunchPrayerIndex();

  static Future<void> checkLaunchNotification() async {
    await initialize();
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return;
      final response = details.notificationResponse;
      if (response == null) return;
      _handleNotificationPayload(response.payload);
    } catch (error) {
      debugPrint('Could not read launch notification: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // Android settings shortcut
  // ---------------------------------------------------------------------------

  static Future<void> openAndroidNotificationSettings() async {
    if (kIsWeb) return;
    try {
      final intent = AndroidIntent(
        action: 'android.settings.APP_NOTIFICATION_SETTINGS',
        arguments: <String, dynamic>{
          'android.provider.extra.APP_PACKAGE': androidPackageName,
        },
      );
      await intent.launch();
    } catch (error) {
      debugPrint('Could not open notification settings: $error');
    }
  }

  // ===========================================================================
  // COMPATIBILITY LAYER
  //
  // Keeps the legacy SettingsProvider API working. New code should prefer
  // the primary methods above.
  // ===========================================================================

  static Future<bool> requestPermission({
    bool requestExactAlarms = false,
  }) async {
    final granted = await requestPermissions();
    if (granted && requestExactAlarms) {
      await requestExactAlarmPermission();
    }
    return granted;
  }

  static Future<bool> refreshPermissionStatus() =>
      refreshNotificationPermissionStatus();

  static Future<void> openNotificationSettings() =>
      openAndroidNotificationSettings();

  static Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id);
    await _plugin.cancel(id + 100);
  }

  static Future<void> cancelAllPrayerReminders(Iterable<int> ids) async {
    await initialize();
    for (final id in ids) {
      await _plugin.cancel(id);
      await _plugin.cancel(id + 100);
    }
  }

  /// Legacy scheduling entry point used by `SettingsProvider`.
  ///
  /// Honours the caller-supplied `id` so `cancel(id)` stays symmetrical.
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
    await initialize();
    await refreshNotificationPermissionStatus();

    if (!_notificationsEnabled) {
      _lastError = 'Notifications are disabled for this app.';
      return false;
    }

    final now = DateTime.now();
    var prayerTime = DateTime(now.year, now.month, now.day, hour, minute);
    while (!prayerTime.subtract(reminderOffset).isAfter(now)) {
      prayerTime = prayerTime.add(const Duration(days: 1));
    }

    final location = tz.local;
    final scheduled = tz.TZDateTime.from(
      prayerTime.subtract(reminderOffset),
      location,
    );

    await _plugin.cancel(id);
    await _plugin.cancel(id + 100);

    final details = _notificationDetails(
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );

    final payload = prayerIndex == null
        ? null
        : jsonEncode({'prayerId': prayerIndex});

    final localizedTitle = _localize(title, language);
    final localizedBody = _localize(body, language);

    try {
      await _plugin.zonedSchedule(
        id,
        localizedTitle,
        localizedBody,
        scheduled,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      _lastError = null;
      return true;
    } on PlatformException {
      try {
        await _plugin.zonedSchedule(
          id,
          localizedTitle,
          localizedBody,
          scheduled,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
        _lastError =
            'Reminder scheduled; Android may deliver it a little late.';
        return true;
      } catch (error) {
        _lastError = 'Could not schedule reminder: $error';
        return false;
      }
    } catch (error) {
      _lastError = 'Could not schedule reminder: $error';
      return false;
    }
  }
}
