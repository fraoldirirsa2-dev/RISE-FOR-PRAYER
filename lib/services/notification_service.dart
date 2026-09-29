import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Handles:
/// - Android/iOS notification initialization
/// - Notification permissions
/// - Android notification channels
/// - Test notifications
/// - Daily prayer reminders
/// - Sound / vibration settings
/// - Notification tap handling
/// - Launch-from-notification handling
class NotificationService {
  NotificationService._();

  // ---------------------------------------------------------------------------
  // Plugin state
  // ---------------------------------------------------------------------------

  static FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _notificationsEnabled = false;

  static Future<void>? _initialization;

  static String? _lastError;

  static int? _launchPrayerIndex;

  /// Whether the custom Android raw notification sound is available.
  ///
  /// Expected Android file:
  ///
  /// android/app/src/main/res/raw/a.mp3
  ///
  /// Android resource name becomes:
  ///
  /// a
  static bool _customSoundAvailable = true;

  // ---------------------------------------------------------------------------
  // Public state
  // ---------------------------------------------------------------------------

  static bool get isInitialized => _initialized;

  static bool get isAvailable => _initialized && _notificationsEnabled;

  static bool get notificationsEnabled => _notificationsEnabled;

  static String? get lastError => _lastError;

  /// Called when a user taps a prayer notification while the app is running.
  static void Function(int prayerIndex)? onPrayerNotificationTap;

  // ---------------------------------------------------------------------------
  // Android notification icon
  // ---------------------------------------------------------------------------

  /// IMPORTANT:
  ///
  /// This is ONLY the Android notification icon.
  ///
  /// Required file:
  ///
  /// android/app/src/main/res/drawable/notification_icon.png
  ///
  /// Do NOT use:
  /// - ic_launcher
  /// - ic_launcher_rise
  /// - @mipmap/ic_launcher
  ///
  /// flutter_local_notifications expects the resource name without
  /// the file extension.
  static const String _androidIconName = 'notification_icon';

  // ---------------------------------------------------------------------------
  // Sound
  // ---------------------------------------------------------------------------

  /// Android:
  ///
  /// android/app/src/main/res/raw/a.mp3
  static const String _androidRawSoundName = 'a';

  /// iOS:
  ///
  /// a.mp3 must be included in the iOS Runner bundle.
  static const String _iosSoundName = 'a.mp3';

  // ---------------------------------------------------------------------------
  // Notification channels
  // ---------------------------------------------------------------------------

  static const String _soundVibrateChannel = 'prayer_reminders_sound_vibrate_a';

  static const String _soundSilentChannel = 'prayer_reminders_sound_silent_a';

  static const String _silentVibrateChannel = 'prayer_reminders_silent_vibrate';

  static const String _silentChannel = 'prayer_reminders_silent';

  // ---------------------------------------------------------------------------
  // Test notification
  // ---------------------------------------------------------------------------

  static const int _testNotificationId = 9090;

  // ---------------------------------------------------------------------------
  // Android package name
  // ---------------------------------------------------------------------------

  /// IMPORTANT:
  ///
  /// Change this to the exact applicationId from:
  ///
  /// android/app/build.gradle
  ///
  /// or:
  ///
  /// android/app/build.gradle.kts
  ///
  /// Example:
  ///
  /// applicationId "com.example.rise_for_prayer"
  ///
  /// Then use:
  ///
  /// static String androidPackageName = 'com.example.rise_for_prayer';
  ///
  static String androidPackageName = 'com.example.thelot_2';

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initializes notifications only once.
  ///
  /// Multiple callers can safely call this at the same time.
  static Future<void> initialize() {
    if (_initialized) {
      return Future<void>.value();
    }

    return _initialization ??= _initialize().whenComplete(() {
      _initialization = null;
    });
  }

  /// Safe startup helper.
  ///
  /// Notification problems must never prevent the application from starting.
  static Future<void> ensureChannels() async {
    try {
      await initialize();
    } catch (error) {
      debugPrint('Notification initialization failed: $error');
    }
  }

  static Future<void> _initialize() async {
    try {
      // -----------------------------------------------------------------------
      // Timezone
      // -----------------------------------------------------------------------

      tz_data.initializeTimeZones();

      try {
        tz.setLocalLocation(tz.getLocation('Africa/Addis_Ababa'));
      } catch (error) {
        debugPrint('Could not set Addis Ababa timezone: $error');

        // Fallback to the package's local timezone.
        tz.setLocalLocation(tz.local);
      }

      _lastError = null;

      // -----------------------------------------------------------------------
      // Initialize plugin
      // -----------------------------------------------------------------------

      await _initializePlugin();

      final android = _androidPlugin;

      // -----------------------------------------------------------------------
      // Create notification channels
      // -----------------------------------------------------------------------

      await _createChannels(android);

      // -----------------------------------------------------------------------
      // Read notification permission state
      // -----------------------------------------------------------------------

      await _readNotificationStatus(android, clearError: false);

      // -----------------------------------------------------------------------
      // Check whether app was launched from a notification
      // -----------------------------------------------------------------------

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();

      final launchResponse = launchDetails?.notificationResponse;

      if (launchDetails?.didNotificationLaunchApp == true &&
          launchResponse != null) {
        _launchPrayerIndex = _parsePrayerIndex(launchResponse.payload ?? '');
      }

      _initialized = true;

      debugPrint('NotificationService initialized successfully.');

      debugPrint('Notification icon: $_androidIconName');
    } catch (error) {
      _initialized = false;
      _notificationsEnabled = false;

      _lastError = 'Notification setup failed: $error';

      debugPrint('NotificationService initialization error: $error');

      rethrow;
    }
  }

  /// Initializes the plugin using ONLY notification_icon.
  ///
  /// There is intentionally NO ic_launcher fallback.
  ///
  /// Required:
  ///
  /// android/app/src/main/res/drawable/notification_icon.png
  static Future<void> _initializePlugin() async {
    final candidate = FlutterLocalNotificationsPlugin();

    final settings = InitializationSettings(
      android: const AndroidInitializationSettings(_androidIconName),
      iOS: const DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await candidate.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _plugin = candidate;
  }

  // ---------------------------------------------------------------------------
  // Notification tap
  // ---------------------------------------------------------------------------

  static void _onNotificationResponse(NotificationResponse response) {
    final index = _parsePrayerIndex(response.payload ?? '');

    if (index == null) {
      debugPrint('Notification tapped without valid prayer index.');
      return;
    }

    debugPrint('Prayer notification tapped: $index');

    onPrayerNotificationTap?.call(index);
  }

  // ---------------------------------------------------------------------------
  // Platform implementations
  // ---------------------------------------------------------------------------

  static AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  // ---------------------------------------------------------------------------
  // Launch notification
  // ---------------------------------------------------------------------------

  /// Returns the prayer index from the notification that launched the app.
  ///
  /// The value is consumed only once.
  static int? consumeLaunchPrayerIndex() {
    final index = _launchPrayerIndex;

    _launchPrayerIndex = null;

    return index;
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Requests notification permission.
  ///
  /// Exact-alarm permission is requested separately when requested.
  static Future<bool> requestPermission({
    bool requestExactAlarms = false,
  }) async {
    if (!await _ensureInitialized()) {
      return false;
    }

    try {
      final android = _androidPlugin;

      // -----------------------------------------------------------------------
      // Android
      // -----------------------------------------------------------------------

      if (android != null) {
        final granted = await android.requestNotificationsPermission();

        if (granted == false) {
          _notificationsEnabled = false;

          _lastError = 'Notifications are disabled for this app.';

          await _readNotificationStatus(android);

          return false;
        }

        // Exact alarms are optional.
        if (requestExactAlarms) {
          try {
            await android.requestExactAlarmsPermission();
          } catch (error) {
            debugPrint('Exact alarm permission unavailable: $error');

            // Scheduling will fall back to inexact alarms.
          }
        }
      }
      // -----------------------------------------------------------------------
      // iOS
      // -----------------------------------------------------------------------
      else {
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

      debugPrint('Notification permission error: $error');

      return false;
    }
  }

  /// Refreshes the notification permission status.
  static Future<bool> refreshPermissionStatus() async {
    if (!await _ensureInitialized()) {
      return false;
    }

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
      // iOS permission state is handled by requestPermissions.
      _notificationsEnabled = true;
    } else {
      _notificationsEnabled = await android.areNotificationsEnabled() ?? false;
    }

    if (clearError && _notificationsEnabled && _initialized) {
      _lastError = null;
    }
  }

  static Future<bool> _ensureInitialized() async {
    if (_initialized) {
      return true;
    }

    try {
      await initialize();

      return _initialized;
    } catch (error) {
      _lastError ??= 'Notification setup failed: $error';

      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Android notification settings
  // ---------------------------------------------------------------------------

  /// Opens the Android notification settings page for this application.
  static Future<bool> openNotificationSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

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

  // ---------------------------------------------------------------------------
  // Schedule daily prayer reminder
  // ---------------------------------------------------------------------------

  /// Schedules a daily reminder at the requested prayer time.
  ///
  /// [reminderOffset]
  /// Example:
  ///
  /// prayer time = 06:00
  /// offset = 10 minutes
  ///
  /// notification time = 05:50
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
    if (!await _ensureInitialized()) {
      return false;
    }

    if (!await refreshPermissionStatus()) {
      _lastError ??= 'Notifications are disabled for this app.';

      return false;
    }

    try {
      final now = tz.TZDateTime.now(tz.local);

      var prayerTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      var scheduled = prayerTime.subtract(reminderOffset);

      // If today's time has already passed, schedule tomorrow.
      while (!scheduled.isAfter(now)) {
        prayerTime = prayerTime.add(const Duration(days: 1));

        scheduled = prayerTime.subtract(reminderOffset);
      }

      // Prevent duplicate notification IDs.
      await cancel(id);

      final details = _notificationDetails(
        vibrationEnabled: vibrationEnabled,
        soundEnabled: soundEnabled,
      );

      final payload = prayerIndex == null
          ? null
          : jsonEncode(<String, int>{'prayerId': prayerIndex});

      Future<void> schedule(AndroidScheduleMode mode) async {
        await _plugin.zonedSchedule(
          id,
          _localize(title, language),
          _localize(body, language),
          scheduled,
          details,
          payload: payload,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }

      // -----------------------------------------------------------------------
      // Try exact alarm first
      // -----------------------------------------------------------------------

      try {
        await schedule(AndroidScheduleMode.exactAllowWhileIdle);

        _lastError = null;

        debugPrint(
          'Prayer reminder scheduled: '
          'id=$id '
          'time=$scheduled '
          'prayerIndex=$prayerIndex',
        );
      }
      // -----------------------------------------------------------------------
      // Fall back to inexact alarm
      // -----------------------------------------------------------------------
      on PlatformException catch (error) {
        debugPrint('Exact scheduling failed: $error');

        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);

        _lastError =
            'Reminder scheduled; Android may deliver '
            'it a little late.';
      }

      return true;
    } catch (error) {
      _lastError = 'Could not schedule reminder: $error';

      debugPrint('Schedule reminder error: $error');

      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Test notification
  // ---------------------------------------------------------------------------

  /// Displays an immediate test notification.
  ///
  /// This does NOT modify the daily prayer schedule.
  static Future<bool> showTestNotification({
    required String title,
    required String body,
    required bool vibrationEnabled,
    required bool soundEnabled,
    required String language,
  }) async {
    if (!await _ensureInitialized()) {
      return false;
    }

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

      debugPrint('Test notification displayed.');

      return true;
    } catch (error) {
      _lastError = 'Could not show test notification: $error';

      debugPrint('Test notification error: $error');

      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Notification details
  // ---------------------------------------------------------------------------

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
        presentAlert: true,
        presentBadge: true,
        presentSound: soundEnabled,
        sound: soundEnabled ? _iosSoundName : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cancellation
  // ---------------------------------------------------------------------------

  /// Cancels all notifications.
  static Future<void> cancelAll() async {
    if (!await _ensureInitialized()) {
      return;
    }

    await _plugin.cancelAll();
  }

  /// Cancels all supplied prayer reminder IDs.
  static Future<void> cancelAllPrayerReminders(Iterable<int> ids) async {
    for (final id in ids) {
      await cancel(id);
    }
  }

  /// Cancels one notification.
  ///
  /// Also cancels id + 100 to remain compatible with
  /// older versions of the scheduling implementation.
  static Future<void> cancel(int id) async {
    if (!await _ensureInitialized()) {
      return;
    }

    await _plugin.cancel(id);

    // Compatibility with previous notification IDs.
    await _plugin.cancel(id + 100);
  }

  // ---------------------------------------------------------------------------
  // Android notification channels
  // ---------------------------------------------------------------------------

  static Future<void> _createChannels(
    AndroidFlutterLocalNotificationsPlugin? android,
  ) async {
    if (android == null) {
      return;
    }

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
      // If custom sound creation fails, recreate the
      // channel without the custom sound.
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
              'Reminder sound resource '
              '"$_androidRawSoundName" is missing; '
              'reminders will use the default sound.';

          return;
        } catch (fallbackError) {
          debugPrint(
            'Could not create fallback channel '
            '${channel.id}: $fallbackError',
          );
        }
      }

      _lastError =
          'Notification channel "${channel.id}" '
          'could not be created: $error';

      debugPrint('Notification channel error: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // Select channel
  // ---------------------------------------------------------------------------

  static String _channelId({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) {
    if (soundEnabled && vibrationEnabled) {
      return _soundVibrateChannel;
    }

    if (soundEnabled) {
      return _soundSilentChannel;
    }

    if (vibrationEnabled) {
      return _silentVibrateChannel;
    }

    return _silentChannel;
  }

  // ---------------------------------------------------------------------------
  // Localization
  // ---------------------------------------------------------------------------

  /// Supports:
  ///
  /// Amharic|English
  ///
  /// Example:
  ///
  /// 'ጸሎት ጊዜ ደርሷል|It is time for prayer'
  static String _localize(String value, String language) {
    final parts = value.split('|');

    if (parts.length < 2) {
      return value;
    }

    return language.toLowerCase() == 'en'
        ? parts.last.trim()
        : parts.first.trim();
  }

  // ---------------------------------------------------------------------------
  // Parse notification payload
  // ---------------------------------------------------------------------------

  static int? _parsePrayerIndex(String payload) {
    if (payload.isEmpty) {
      return null;
    }

    // Direct integer payload.
    final directIndex = int.tryParse(payload);

    if (directIndex != null) {
      return directIndex;
    }

    // JSON payload:
    //
    // {"prayerId": 0}
    try {
      final decoded = jsonDecode(payload);

      if (decoded is Map) {
        final prayerId = decoded['prayerId'];

        if (prayerId is int) {
          return prayerId;
        }

        return int.tryParse(prayerId?.toString() ?? '');
      }
    } catch (error) {
      debugPrint('Could not parse notification payload: $error');
    }

    return null;
  }
}
