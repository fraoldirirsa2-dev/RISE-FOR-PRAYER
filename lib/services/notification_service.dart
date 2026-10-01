import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

@visibleForTesting
tz.TZDateTime nextPrayerReminderDate({
  required tz.Location location,
  required tz.TZDateTime now,
  required int hour,
  required int minute,
  required int offsetMinutes,
}) {
  final prayerToday = tz.TZDateTime(
    location,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  var reminderDate = prayerToday.subtract(Duration(minutes: offsetMinutes));

  if (!reminderDate.isAfter(now)) {
    final prayerTomorrow = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
    reminderDate = prayerTomorrow.subtract(Duration(minutes: offsetMinutes));
  }

  return reminderDate;
}

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

  // Compatibility getter used by settings/provider code.
  static bool get isAvailable => _notificationsEnabled;

  static String? get lastError => _lastError;

  // Your Android applicationId from android/app/build.gradle.kts
  static const String androidPackageName = 'com.example.thelot_2';

  // Android notification icon:
  // android/app/src/main/res/drawable/ic_notification.xml
  // Use a resource that is actually present in the app so Android does not
  // throw PlatformException(invalid_icon).
  static const String _androidIconName = 'ic_notification';

  static String get androidNotificationIconName => _androidIconName;

  // Android sound:
  // android/app/src/main/res/raw/a.mp3
  static const String _androidRawSoundName = 'a';

  // iOS sound
  static const String _iosSoundName = 'a.mp3';

  // Ethiopia / Addis Ababa
  static const String _timezoneName = 'Africa/Addis_Ababa';

  // New channel IDs so old Android channel settings don't interfere.
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

  static void Function(int prayerIndex)? onPrayerNotificationTap;

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  static Future<void> initialize() {
    if (_initialized) {
      return Future<void>.value();
    }

    return _initialization ??= _initializeInternal();
  }

  static Future<void> _initializeInternal() async {
    try {
      if (_initialized) return;

      // Initialize timezone database.
      tz.initializeTimeZones();

      // Set Addis Ababa timezone.
      try {
        tz.setLocalLocation(tz.getLocation(_timezoneName));
      } catch (error) {
        debugPrint('Could not set Addis Ababa timezone: $error');
      }

      const androidSettings = AndroidInitializationSettings(_androidIconName);

      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      final initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      await _createNotificationChannels();

      _initialized = true;

      await checkLaunchNotification();

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
  // PERMISSION STATUS
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

        // On older Android versions a null result should not
        // incorrectly disable notifications.
        _notificationsEnabled = enabled ?? true;

        debugPrint(
          'Android notifications enabled: '
          '$_notificationsEnabled',
        );

        return _notificationsEnabled;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      if (ios != null) {
        final permissions = await ios.checkPermissions();

        _notificationsEnabled = permissions?.isEnabled ?? true;

        return _notificationsEnabled;
      }

      _notificationsEnabled = true;
      return true;
    } catch (error) {
      debugPrint('Could not read notification permission: $error');

      // Avoid falsely reporting unavailable on older devices.
      _notificationsEnabled = true;

      return true;
    }
  }

  // Compatibility alias.
  static Future<bool> refreshPermissionStatus() {
    return refreshNotificationPermissionStatus();
  }

  // ---------------------------------------------------------------------------
  // REQUEST PERMISSION
  // ---------------------------------------------------------------------------

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
          final current = await android.areNotificationsEnabled();

          _notificationsEnabled = current ?? true;
        } else {
          _notificationsEnabled = result;
        }

        debugPrint(
          'Notification permission: '
          '$_notificationsEnabled',
        );

        if (requestExactAlarms) {
          await requestExactAlarmPermission();
        }

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

  // Compatibility alias.
  static Future<bool> requestPermission({bool requestExactAlarms = false}) {
    return requestPermissions(requestExactAlarms: requestExactAlarms);
  }

  // ---------------------------------------------------------------------------
  // EXACT ALARM
  // ---------------------------------------------------------------------------

  static Future<bool> canScheduleExactNotifications() async {
    if (kIsWeb) return false;

    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (android == null) return false;

      final result = await android.canScheduleExactNotifications();

      return result ?? false;
    } catch (error) {
      debugPrint('Exact alarm check failed: $error');

      return false;
    }
  }

  static Future<bool> requestExactAlarmPermission() async {
    if (kIsWeb) return false;

    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (android == null) return false;

      final alreadyGranted = await android.canScheduleExactNotifications();

      if (alreadyGranted == true) {
        return true;
      }

      final result = await android.requestExactAlarmsPermission();

      final after = await android.canScheduleExactNotifications();

      debugPrint(
        'Exact alarm permission: '
        'requested=$result, granted=$after',
      );

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
  // ANDROID CHANNELS
  // ---------------------------------------------------------------------------

  static Future<void> _createNotificationChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) return;

    try {
      // Sound + vibration
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

      // Sound only
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

      // Vibration only
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

      // Silent
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

      debugPrint('Notification channels created successfully.');
    } catch (error, stackTrace) {
      _customSoundAvailable = false;

      debugPrint('Custom notification sound unavailable: $error');

      debugPrintStack(stackTrace: stackTrace);

      // Fallback channels without custom sound.
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
        debugPrint(
          'Fallback notification channels failed: '
          '$fallbackError',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // TEST NOTIFICATION
  // ---------------------------------------------------------------------------

  static Future<bool> showTestNotification({
    String? title,
    String? body,
    bool vibrationEnabled = true,
    bool soundEnabled = true,
    String language = 'en',
  }) async {
    await initialize();

    var enabled = await refreshNotificationPermissionStatus();

    if (!enabled) {
      enabled = await requestPermissions();
    }

    if (!enabled) {
      _lastError = 'Notification permission is disabled.';

      return false;
    }

    try {
      final parsedTitle = _selectLanguageText(
        title,
        language,
        fallbackAmharic: 'የጸሎት ማሳሰቢያ ሙከራ',
        fallbackEnglish: 'Prayer reminder test',
      );

      final parsedBody = _selectLanguageText(
        body,
        language,
        fallbackAmharic: 'ማሳሰቢያዎች እንዴት እንደሚሰሙ ለመፈተሽ ነው።',
        fallbackEnglish:
            'This checks your reminder sound and vibration settings.',
      );

      await _plugin.show(
        _testNotificationId,
        parsedTitle,
        parsedBody,
        _notificationDetails(sound: soundEnabled, vibration: vibrationEnabled),
        payload: jsonEncode({'prayerId': 0, 'test': true}),
      );

      debugPrint('Test notification sent successfully.');

      return true;
    } catch (error, stackTrace) {
      _lastError = error.toString();

      debugPrint('Test notification failed: $error');

      debugPrintStack(stackTrace: stackTrace);

      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // DAILY REMINDER
  // ---------------------------------------------------------------------------

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

    if (hour < 0 || hour > 23) {
      _lastError = 'Invalid reminder hour: $hour';

      return false;
    }

    if (minute < 0 || minute > 59) {
      _lastError = 'Invalid reminder minute: $minute';

      return false;
    }

    const allowedOffsets = <int>{0, 5, 10, 15};

    if (!allowedOffsets.contains(reminderOffset.inMinutes)) {
      _lastError = 'Reminder offset must be 0, 5, 10 or 15 minutes.';

      return false;
    }

    if (!await refreshNotificationPermissionStatus()) {
      _lastError = 'Notification permission is disabled.';

      return false;
    }

    try {
      final scheduledDate = nextPrayerReminderDate(
        location: tz.local,
        now: tz.TZDateTime.now(tz.local),
        hour: hour,
        minute: minute,
        offsetMinutes: reminderOffset.inMinutes,
      );

      final parsedTitle = _selectLanguageText(
        title,
        language,
        fallbackAmharic: 'የጸሎት ማሳሰቢያ',
        fallbackEnglish: 'Prayer reminder',
      );

      final parsedBody = _selectLanguageText(
        body,
        language,
        fallbackAmharic: 'የጸሎት ጊዜ ደርሷል።',
        fallbackEnglish: 'It is time for prayer.',
      );

      final payload = jsonEncode({
        'prayerId': prayerIndex ?? 0,
        'reminderMinutes': reminderOffset.inMinutes,
      });

      await _scheduleZoned(
        id: id,
        title: parsedTitle,
        body: parsedBody,
        scheduledDate: scheduledDate,
        details: _notificationDetails(
          sound: soundEnabled,
          vibration: vibrationEnabled,
        ),
        payload: payload,
      );

      debugPrint(
        'Daily reminder scheduled: '
        'id=$id '
        'time=$scheduledDate '
        'offset=${reminderOffset.inMinutes} '
        'prayerIndex=$prayerIndex',
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
  // SINGLE PRAYER REMINDER
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
    if (prayerIndex < 0 || prayerIndex >= 7) {
      _lastError = 'Invalid prayer index: $prayerIndex';

      return false;
    }

    if (![0, 5, 10, 15].contains(reminderMinutes)) {
      _lastError = 'Invalid reminder offset: $reminderMinutes';

      return false;
    }

    return scheduleDailyReminder(
      id: notificationId(prayerIndex, reminderMinutes),
      title: title ?? '${_prayerNames[prayerIndex]} • የጸሎት ጊዜ',
      body:
          body ??
          (reminderMinutes == 0
              ? 'የጸሎት ጊዜ ደርሷል።'
              : 'የጸሎት ጊዜ ከ$reminderMinutes ደቂቃ በኋላ ነው።'),
      hour: prayerTime.hour,
      minute: prayerTime.minute,
      vibrationEnabled: vibration,
      soundEnabled: sound,
      reminderOffset: Duration(minutes: reminderMinutes),
      prayerIndex: prayerIndex,
    );
  }

  // ---------------------------------------------------------------------------
  // ALL SEVEN PRAYER REMINDERS
  // ---------------------------------------------------------------------------

  static Future<void> scheduleAllPrayerReminders({
    required List<DateTime> prayerTimes,
    int reminderMinutes = 0,
    bool sound = true,
    bool vibration = true,
  }) async {
    if (prayerTimes.length < 7) {
      throw ArgumentError('Seven prayer times are required.');
    }

    await initialize();

    if (!await refreshNotificationPermissionStatus()) {
      final granted = await requestPermissions();

      if (!granted) {
        throw StateError('Notification permission is disabled.');
      }
    }

    for (var index = 0; index < 7; index++) {
      await schedulePrayerReminder(
        prayerIndex: index,
        prayerTime: prayerTimes[index],
        reminderMinutes: reminderMinutes,
        sound: sound,
        vibration: vibration,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ZONED SCHEDULING
  // ---------------------------------------------------------------------------
  //
  // IMPORTANT:
  // flutter_local_notifications 17.2.3 supports androidScheduleMode.
  // androidAllowWhileIdle is deprecated and is intentionally NOT used.
  //
  // uiLocalNotificationDateInterpretation remains required for this
  // plugin version.
  // ---------------------------------------------------------------------------

  static Future<void> _scheduleZoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    String? payload,
  }) async {
    final scheduleMode = await _getScheduleMode();

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,

        // ✅ New API.
        // Replaces deprecated androidAllowWhileIdle.
        androidScheduleMode: scheduleMode,

        // ✅ Required by flutter_local_notifications 17.2.3.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,

        payload: payload,

        // Repeat every day at the same time.
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint(
        'Zoned notification scheduled successfully: '
        'id=$id mode=$scheduleMode',
      );
    } catch (error) {
      debugPrint(
        'Primary notification scheduling failed: '
        '$error',
      );

      // Fallback to inexact scheduling.
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,

          // ✅ New API.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,

          // ✅ Still required in version 17.2.3.
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,

          payload: payload,

          matchDateTimeComponents: DateTimeComponents.time,
        );

        debugPrint('Fallback notification scheduling succeeded.');
      } catch (fallbackError) {
        debugPrint(
          'Fallback notification scheduling failed: '
          '$fallbackError',
        );

        rethrow;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATION DETAILS
  // ---------------------------------------------------------------------------

  static NotificationDetails _notificationDetails({
    required bool sound,
    required bool vibration,
  }) {
    final channelId = _channelId(sound: sound, vibration: vibration);

    final androidDetails = AndroidNotificationDetails(
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

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: sound,
      sound: sound ? _iosSoundName : null,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
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
  // NOTIFICATION IDS
  // ---------------------------------------------------------------------------

  static int notificationId(int prayerIndex, int reminderMinutes) {
    return 1000 + prayerIndex * 100 + reminderMinutes;
  }

  // ---------------------------------------------------------------------------
  // CANCEL
  // ---------------------------------------------------------------------------

  static Future<void> cancel(int id) async {
    await initialize();

    await _plugin.cancel(id);
  }

  static Future<void> cancelPrayerReminder({
    required int prayerIndex,
    required int reminderMinutes,
  }) async {
    await cancel(notificationId(prayerIndex, reminderMinutes));
  }

  static Future<void> cancelPrayer({required int prayerIndex}) async {
    for (final minutes in [0, 5, 10, 15]) {
      await cancelPrayerReminder(
        prayerIndex: prayerIndex,
        reminderMinutes: minutes,
      );
    }
  }

  static Future<void> cancelAllPrayerReminders([Iterable<int>? ids]) async {
    await initialize();

    if (ids != null) {
      for (final id in ids) {
        await _plugin.cancel(id);
      }

      return;
    }

    for (var prayerIndex = 0; prayerIndex < 7; prayerIndex++) {
      for (final minutes in [0, 5, 10, 15]) {
        await _plugin.cancel(notificationId(prayerIndex, minutes));
      }
    }
  }

  static Future<void> cancelAll() async {
    await initialize();

    await _plugin.cancelAll();
  }

  // ---------------------------------------------------------------------------
  // LANGUAGE
  // ---------------------------------------------------------------------------

  static String _selectLanguageText(
    String? value,
    String language, {
    required String fallbackAmharic,
    required String fallbackEnglish,
  }) {
    if (value == null || value.trim().isEmpty) {
      return language == 'eth' ? fallbackAmharic : fallbackEnglish;
    }

    final parts = value.split('|');

    if (parts.length >= 2) {
      return language == 'eth'
          ? parts.first.trim()
          : parts.sublist(1).join('|').trim();
    }

    return value;
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATION TAP
  // ---------------------------------------------------------------------------

  static void _onNotificationResponse(NotificationResponse response) {
    _handleNotificationPayload(response.payload);
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    debugPrint(
      'Notification tapped in background: '
      '${response.payload}',
    );
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
      debugPrint(
        'Could not parse notification payload: '
        '$error',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // APP LAUNCHED BY NOTIFICATION
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
      debugPrint(
        'Could not check launch notification: '
        '$error',
      );
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
    if (kIsWeb) return;

    final intent = AndroidIntent(
      action: 'android.settings.APP_NOTIFICATION_SETTINGS',
      arguments: <String, dynamic>{
        'android.provider.extra.APP_PACKAGE': androidPackageName,
      },
    );

    await intent.launch();
  }

  static Future<void> openExactAlarmSettings() async {
    if (kIsWeb) return;

    final intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      arguments: <String, dynamic>{
        'android.provider.extra.APP_PACKAGE': androidPackageName,
      },
    );

    await intent.launch();
  }
}
