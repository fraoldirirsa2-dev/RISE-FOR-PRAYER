import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static Future<void>? _initialization;

  static bool _notificationsEnabled = false;
  static bool _customSoundAvailable = true;

  static String? _lastError;
  static int? _launchPrayerIndex;

  static Future<void>? get initialization => _initialization;

  static bool get notificationsEnabled => _notificationsEnabled;

  static String? get lastError => _lastError;

  static const String androidPackageName = 'com.example.thelot_2';

  static const String _androidIconName = 'notification_icon';
  static const String _androidRawSoundName = 'a';
  static const String _iosSoundName = 'a.mp3';

  static const String _timezoneName = 'Africa/Addis_Ababa';

  // Use new channel IDs so Android does not keep the settings
  // from old/broken notification channels.
  static const String _soundVibrateChannel =
      'prayer_reminders_sound_vibrate_v2';

  static const String _soundSilentChannel = 'prayer_reminders_sound_silent_v2';

  static const String _silentVibrateChannel =
      'prayer_reminders_silent_vibrate_v2';

  static const String _silentChannel = 'prayer_reminders_silent_v2';

  static const int _testNotificationId = 9090;

  static const List<String> _prayerNames = [
    'ነግህ',
    'ሠለስት',
    'ቀትር',
    'ተሰዓት',
    'ሠርክ',
    'ንዋም',
    'መንፈቀ ሌሊት',
  ];

  /// Called when the user taps a prayer notification.
  static void Function(int prayerIndex)? onPrayerNotificationTap;

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  static Future<void> initialize() {
    if (_initialized) {
      return Future.value();
    }

    return _initialization ??= _initializeInternal();
  }

  static Future<void> _initializeInternal() async {
    try {
      if (_initialized) {
        return;
      }

      // Initialize timezone database.
      tz.initializeTimeZones();

      try {
        tz.setLocalLocation(tz.getLocation(_timezoneName));
      } catch (error) {
        debugPrint('Could not set Addis Ababa timezone: $error');
      }

      const androidSettings = AndroidInitializationSettings(_androidIconName);

      final initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _plugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      await _createNotificationChannels();

      _initialized = true;

      // Read launch notification information.
      await checkLaunchNotification();

      // Read current notification permission.
      await refreshNotificationPermissionStatus();

      debugPrint('NotificationService initialized successfully.');
    } catch (error, stackTrace) {
      _lastError = error.toString();

      debugPrint('NotificationService initialization error: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // PERMISSIONS
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

        // On older Android/plugin combinations this can be null.
        // Null should not automatically mean "permission denied".
        _notificationsEnabled = enabled ?? true;

        debugPrint('Android notification enabled: $_notificationsEnabled');

        return _notificationsEnabled;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            DarwinFlutterLocalNotificationsPlugin
          >();

      if (ios != null) {
        final settings = await ios.checkPermissions();

        _notificationsEnabled = settings?.isEnabled ?? true;

        return _notificationsEnabled;
      }

      _notificationsEnabled = true;
      return true;
    } catch (error) {
      debugPrint('Could not read notification permission: $error');

      // Do not falsely mark Android <13 as disabled.
      _notificationsEnabled = true;

      return true;
    }
  }

  static Future<bool> requestPermissions({
    bool requestExactAlarms = false,
  }) async {
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

        if (result == null) {
          // Older Android versions may return null because
          // POST_NOTIFICATIONS runtime permission does not apply.
          final current = await android.areNotificationsEnabled();
          _notificationsEnabled = current ?? true;
        } else {
          _notificationsEnabled = result;
        }

        debugPrint('Notification permission result: $_notificationsEnabled');

        if (requestExactAlarms) {
          await requestExactAlarmPermission();
        }

        return _notificationsEnabled;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            DarwinFlutterLocalNotificationsPlugin
          >();

      if (ios != null) {
        final result = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

        _notificationsEnabled = result ?? true;
        return _notificationsEnabled;
      }

      _notificationsEnabled = true;
      return true;
    } catch (error, stackTrace) {
      _lastError = error.toString();

      debugPrint('Notification permission request error: $error');
      debugPrintStack(stackTrace: stackTrace);

      await refreshNotificationPermissionStatus();

      return _notificationsEnabled;
    }
  }

  /// Compatibility alias.
  static Future<bool> requestPermission({bool requestExactAlarms = false}) {
    return requestPermissions(requestExactAlarms: requestExactAlarms);
  }

  // ---------------------------------------------------------------------------
  // EXACT ALARM
  // ---------------------------------------------------------------------------

  static Future<bool> canScheduleExactNotifications() async {
    if (kIsWeb) {
      return false;
    }

    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (android == null) {
        return false;
      }

      final result = await android.canScheduleExactNotifications();

      return result ?? false;
    } catch (error) {
      debugPrint('Exact alarm status check failed: $error');
      return false;
    }
  }

  static Future<bool> requestExactAlarmPermission() async {
    if (kIsWeb) {
      return false;
    }

    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (android == null) {
        return false;
      }

      final current = await android.canScheduleExactNotifications();

      if (current == true) {
        return true;
      }

      final result = await android.requestExactAlarmsPermission();

      final after = await android.canScheduleExactNotifications();

      debugPrint('Exact alarm permission: requested=$result, granted=$after');

      return after ?? result ?? false;
    } catch (error) {
      debugPrint('Exact alarm permission request failed: $error');
      return false;
    }
  }

  static Future<AndroidScheduleMode> _getScheduleMode() async {
    final exact = await canScheduleExactNotifications();

    if (exact) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  // ---------------------------------------------------------------------------
  // CHANNELS
  // ---------------------------------------------------------------------------

  static Future<void> _createNotificationChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) {
      return;
    }

    try {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          _soundVibrateChannel,
          'Prayer reminders',
          description: 'Prayer reminders with sound and vibration.',
          importance: Importance.max,
          playSound: _customSoundAvailable,
          sound: _customSoundAvailable
              ? const RawResourceAndroidNotificationSound('a')
              : null,
          enableVibration: true,
          showBadge: true,
        ),
      );

      await android.createNotificationChannel(
        AndroidNotificationChannel(
          _soundSilentChannel,
          'Prayer reminders - sound only',
          description: 'Prayer reminders with sound without vibration.',
          importance: Importance.max,
          playSound: _customSoundAvailable,
          sound: _customSoundAvailable
              ? const RawResourceAndroidNotificationSound('a')
              : null,
          enableVibration: false,
          showBadge: true,
        ),
      );

      await android.createNotificationChannel(
        AndroidNotificationChannel(
          _silentVibrateChannel,
          'Prayer reminders - vibration',
          description: 'Prayer reminders with vibration without sound.',
          importance: Importance.max,
          playSound: false,
          enableVibration: true,
          showBadge: true,
        ),
      );

      await android.createNotificationChannel(
        AndroidNotificationChannel(
          _silentChannel,
          'Prayer reminders - silent',
          description: 'Silent prayer reminders.',
          importance: Importance.max,
          playSound: false,
          enableVibration: false,
          showBadge: true,
        ),
      );

      debugPrint('Notification channels created.');
    } catch (error, stackTrace) {
      _customSoundAvailable = false;

      debugPrint('Custom notification sound unavailable: $error');
      debugPrintStack(stackTrace: stackTrace);

      // Create silent channels as a safe fallback.
      try {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _soundVibrateChannel,
            'Prayer reminders',
            description: 'Prayer reminders.',
            importance: Importance.max,
            playSound: false,
            enableVibration: true,
            showBadge: true,
          ),
        );

        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _silentChannel,
            'Prayer reminders - silent',
            description: 'Silent prayer reminders.',
            importance: Importance.max,
            playSound: false,
            enableVibration: false,
            showBadge: true,
          ),
        );
      } catch (fallbackError) {
        debugPrint('Fallback channel creation failed: $fallbackError');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // TEST NOTIFICATION
  // ---------------------------------------------------------------------------

  static Future<bool> showTestNotification() async {
    await initialize();

    var enabled = await refreshNotificationPermissionStatus();

    if (!enabled) {
      enabled = await requestPermissions();
    }

    if (!enabled) {
      debugPrint('Test notification cancelled: notifications are disabled.');
      return false;
    }

    try {
      await _plugin.show(
        _testNotificationId,
        'ለጸሎት ተነሱ',
        'ይህ የማሳወቂያ ሙከራ ነው።',
        _notificationDetails(sound: true, vibration: true),
        payload: jsonEncode({'prayerId': 0}),
      );

      debugPrint('Test notification sent.');

      return true;
    } catch (error, stackTrace) {
      _lastError = error.toString();

      debugPrint('Test notification failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // SCHEDULE PRAYER REMINDER
  // ---------------------------------------------------------------------------

  static Future<bool> schedulePrayerReminder({
    required int prayerIndex,
    required DateTime prayerTime,
    int reminderMinutes = 0,
    bool sound = true,
    bool vibration = true,
    String? title,
    String? body,
  }) async {
    await initialize();

    if (prayerIndex < 0 || prayerIndex >= 7) {
      debugPrint('Invalid prayer index: $prayerIndex');
      return false;
    }

    if (![0, 5, 10, 15].contains(reminderMinutes)) {
      debugPrint('Invalid reminder offset: $reminderMinutes');
      return false;
    }

    if (!await refreshNotificationPermissionStatus()) {
      debugPrint('Cannot schedule prayer reminder: notifications disabled.');
      return false;
    }

    final now = tz.TZDateTime.now(tz.local);

    var scheduledTime = tz.TZDateTime.from(
      prayerTime,
      tz.local,
    ).subtract(Duration(minutes: reminderMinutes));

    // If this occurrence has already passed, schedule tomorrow.
    if (!scheduledTime.isAfter(now)) {
      scheduledTime = tz.TZDateTime(
        tz.local,
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day + 1,
        scheduledTime.hour,
        scheduledTime.minute,
        scheduledTime.second,
      );
    }

    final id = notificationId(prayerIndex, reminderMinutes);

    final notificationTitle = title ?? _defaultTitle(prayerIndex);

    final notificationBody = body ?? _defaultBody(prayerIndex, reminderMinutes);

    final details = _notificationDetails(sound: sound, vibration: vibration);

    try {
      final mode = await _getScheduleMode();

      await _zonedScheduleWithFallback(
        id: id,
        title: notificationTitle,
        body: notificationBody,
        scheduledDate: scheduledTime,
        details: details,
        payload: jsonEncode({
          'prayerId': prayerIndex,
          'reminderMinutes': reminderMinutes,
        }),
        scheduleMode: mode,
      );

      debugPrint(
        'Scheduled prayer $prayerIndex '
        '($notificationTitle) '
        'at $scheduledTime '
        'offset=$reminderMinutes '
        'mode=$mode',
      );

      return true;
    } catch (error, stackTrace) {
      _lastError = error.toString();

      debugPrint('Failed to schedule prayer $prayerIndex: $error');
      debugPrintStack(stackTrace: stackTrace);

      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // SCHEDULE ALL PRAYER REMINDERS
  // ---------------------------------------------------------------------------

  static Future<void> scheduleAllPrayerReminders({
    required List<DateTime> prayerTimes,
    int reminderMinutes = 0,
    bool sound = true,
    bool vibration = true,
  }) async {
    await initialize();

    if (prayerTimes.length < 7) {
      throw ArgumentError('Seven prayer times are required.');
    }

    if (!await refreshNotificationPermissionStatus()) {
      final granted = await requestPermissions();

      if (!granted) {
        throw StateError('Notification permission is disabled.');
      }
    }

    // Cancel old reminders for this offset first.
    for (var prayerIndex = 0; prayerIndex < 7; prayerIndex++) {
      await cancelPrayerReminder(
        prayerIndex: prayerIndex,
        reminderMinutes: reminderMinutes,
      );
    }

    for (var prayerIndex = 0; prayerIndex < 7; prayerIndex++) {
      await schedulePrayerReminder(
        prayerIndex: prayerIndex,
        prayerTime: prayerTimes[prayerIndex],
        reminderMinutes: reminderMinutes,
        sound: sound,
        vibration: vibration,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // SCHEDULE DAILY REMINDER
  // ---------------------------------------------------------------------------

  static Future<bool> scheduleDailyReminder({
    required int id,
    required DateTime time,
    required String title,
    required String body,
    bool sound = true,
    bool vibration = true,
    String? payload,
  }) async {
    await initialize();

    if (!await refreshNotificationPermissionStatus()) {
      return false;
    }

    var scheduledDate = tz.TZDateTime.from(time, tz.local);

    final now = tz.TZDateTime.now(tz.local);

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        scheduledDate.hour,
        scheduledDate.minute,
        scheduledDate.second,
      );
    }

    try {
      final details = _notificationDetails(sound: sound, vibration: vibration);

      final mode = await _getScheduleMode();

      await _zonedScheduleWithFallback(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        details: details,
        payload: payload,
        scheduleMode: mode,
      );

      return true;
    } catch (error, stackTrace) {
      _lastError = error.toString();

      debugPrint('Daily reminder scheduling failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // ZONED SCHEDULE
  // ---------------------------------------------------------------------------

  static Future<void> _zonedScheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    required AndroidScheduleMode scheduleMode,
    String? payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: scheduleMode,
        payload: payload,

        // Prayer reminders repeat every day at this time.
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (error) {
      debugPrint('Primary notification schedule failed: $error');

      // If exact scheduling fails, always try inexact scheduling.
      if (scheduleMode != AndroidScheduleMode.inexactAllowWhileIdle) {
        debugPrint('Retrying notification using inexact scheduling...');

        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
          matchDateTimeComponents: DateTimeComponents.time,
        );

        debugPrint('Inexact notification scheduling succeeded.');

        return;
      }

      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // DETAILS
  // ---------------------------------------------------------------------------

  static NotificationDetails _notificationDetails({
    required bool sound,
    required bool vibration,
  }) {
    final channelId = _channelId(sound: sound, vibration: vibration);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          _channelName(channelId),
          channelDescription: 'Ethiopian Orthodox prayer reminders.',
          importance: Importance.max,
          priority: Priority.high,
          icon: _androidIconName,
          playSound: sound && _customSoundAvailable,
          sound: sound && _customSoundAvailable
              ? const RawResourceAndroidNotificationSound(_androidRawSoundName)
              : null,
          enableVibration: vibration,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          autoCancel: true,
          ongoing: false,
          showWhen: true,
        );

    return NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: sound,
        sound: sound ? _iosSoundName : null,
      ),
    );
  }

  static String _channelId({required bool sound, required bool vibration}) {
    if (sound && vibration) {
      return _soundVibrateChannel;
    }

    if (sound && !vibration) {
      return _soundSilentChannel;
    }

    if (!sound && vibration) {
      return _silentVibrateChannel;
    }

    return _silentChannel;
  }

  static String _channelName(String channelId) {
    switch (channelId) {
      case _soundVibrateChannel:
        return 'Prayer reminders';

      case _soundSilentChannel:
        return 'Prayer reminders - sound only';

      case _silentVibrateChannel:
        return 'Prayer reminders - vibration';

      case _silentChannel:
        return 'Prayer reminders - silent';

      default:
        return 'Prayer reminders';
    }
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATION IDs
  // ---------------------------------------------------------------------------

  static int notificationId(int prayerIndex, int reminderMinutes) {
    return 1000 + prayerIndex * 100 + reminderMinutes;
  }

  // ---------------------------------------------------------------------------
  // CANCEL
  // ---------------------------------------------------------------------------

  static Future<void> cancelPrayerReminder({
    required int prayerIndex,
    required int reminderMinutes,
  }) async {
    await initialize();

    await _plugin.cancel(notificationId(prayerIndex, reminderMinutes));
  }

  static Future<void> cancelPrayer({required int prayerIndex}) async {
    await initialize();

    for (final minutes in [0, 5, 10, 15]) {
      await cancelPrayerReminder(
        prayerIndex: prayerIndex,
        reminderMinutes: minutes,
      );
    }
  }

  static Future<void> cancelAllPrayerReminders() async {
    await initialize();

    for (var prayerIndex = 0; prayerIndex < 7; prayerIndex++) {
      for (final minutes in [0, 5, 10, 15]) {
        await cancelPrayerReminder(
          prayerIndex: prayerIndex,
          reminderMinutes: minutes,
        );
      }
    }
  }

  static Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  // ---------------------------------------------------------------------------
  // TITLES / BODY
  // ---------------------------------------------------------------------------

  static String _defaultTitle(int prayerIndex) {
    if (prayerIndex < 0 || prayerIndex >= _prayerNames.length) {
      return 'ለጸሎት ተነሱ';
    }

    return '${_prayerNames[prayerIndex]} • የጸሎት ጊዜ';
  }

  static String _defaultBody(int prayerIndex, int reminderMinutes) {
    if (reminderMinutes == 0) {
      return 'የጸሎት ጊዜ ደርሷል።';
    }

    return 'የጸሎት ጊዜ ከ$reminderMinutes ደቂቃ በኋላ ነው።';
  }

  // ---------------------------------------------------------------------------
  // TAP HANDLING
  // ---------------------------------------------------------------------------

  static void _onNotificationResponse(NotificationResponse response) {
    _handleNotificationPayload(response.payload);
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    // Do not attempt navigation from a background isolate.
    // The launch handler will handle opening the prayer screen.
    debugPrint('Notification tapped in background: ${response.payload}');
  }

  static void _handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(payload);

      if (decoded is Map<String, dynamic>) {
        final value = decoded['prayerId'];

        if (value is int) {
          onPrayerNotificationTap?.call(value);
        } else if (value is num) {
          onPrayerNotificationTap?.call(value.toInt());
        }
      }
    } catch (error) {
      debugPrint('Could not parse notification payload: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // LAUNCH FROM NOTIFICATION
  // ---------------------------------------------------------------------------

  static Future<void> checkLaunchNotification() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();

      if (details?.didNotificationLaunchApp != true) {
        return;
      }

      final response = details?.notificationResponse;

      if (response == null) {
        return;
      }

      final payload = response.payload;

      if (payload == null || payload.isEmpty) {
        return;
      }

      try {
        final decoded = jsonDecode(payload);

        if (decoded is Map<String, dynamic>) {
          final value = decoded['prayerId'];

          if (value is int) {
            _launchPrayerIndex = value;
          } else if (value is num) {
            _launchPrayerIndex = value.toInt();
          }
        }
      } catch (error) {
        debugPrint('Launch notification payload error: $error');
      }
    } catch (error) {
      debugPrint('Could not check launch notification: $error');
    }
  }

  static int? consumeLaunchPrayerIndex() {
    final value = _launchPrayerIndex;
    _launchPrayerIndex = null;
    return value;
  }

  // ---------------------------------------------------------------------------
  // ANDROID SETTINGS
  // ---------------------------------------------------------------------------

  static Future<void> openNotificationSettings() async {
    if (kIsWeb) {
      return;
    }

    final intent = AndroidIntent(
      action: 'android.settings.APP_NOTIFICATION_SETTINGS',
      arguments: <String, dynamic>{
        'android.provider.extra.APP_PACKAGE': androidPackageName,
      },
    );

    await intent.launch();
  }

  static Future<void> openExactAlarmSettings() async {
    if (kIsWeb) {
      return;
    }

    final intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      arguments: <String, dynamic>{
        'android.provider.extra.APP_PACKAGE': androidPackageName,
      },
    );

    await intent.launch();
  }
}
