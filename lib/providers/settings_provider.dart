import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rise_for_prayer/data/prayer_reminders.dart';
import 'package:rise_for_prayer/services/notification_service.dart';
import 'package:rise_for_prayer/services/preferences_store.dart';

enum ThemeModeType { light, dark }

class SettingsProvider extends ChangeNotifier {
  ThemeModeType _themeMode = ThemeModeType.dark;

  String _language = 'eth';

  String? _notificationError;

  bool _vibrationEnabled = true;

  bool _notificationSoundEnabled = true;

  bool _remindersEnabled = false;

  int _reminderOffsetMinutes = 0;

  int _scheduledReminderCount = 0;

  bool _onboardingComplete = false;

  bool _testingNotification = false;

  List<bool> _reminderEnabled = List<bool>.filled(7, true);

  Future<void> _saveQueue = Future<void>.value();

  Future<void> _scheduleQueue = Future<void>.value();

  SettingsProvider() {
    _loadSettings();
  }

  // ===========================================================================
  // GETTERS
  // ===========================================================================

  ThemeModeType get themeMode => _themeMode;

  String get language => _language;

  bool get vibrationEnabled => _vibrationEnabled;

  bool get notificationSoundEnabled => _notificationSoundEnabled;

  bool get remindersEnabled => _remindersEnabled;

  int get reminderOffsetMinutes => _reminderOffsetMinutes;

  int get scheduledReminderCount => _scheduledReminderCount;

  bool get notificationPermissionGranted =>
      NotificationService.notificationsEnabled;

  String? get notificationError => _notificationError;

  bool get onboardingComplete => _onboardingComplete;

  bool get testingNotification => _testingNotification;

  List<bool> get reminderEnabled => List<bool>.unmodifiable(_reminderEnabled);

  ThemeMode get materialThemeMode {
    return _themeMode == ThemeModeType.light ? ThemeMode.light : ThemeMode.dark;
  }

  // ===========================================================================
  // THEME
  // ===========================================================================

  void setTheme(String mode) {
    _themeMode = ThemeModeType.values.firstWhere(
      (e) => e.name == mode,
      orElse: () => ThemeModeType.dark,
    );

    unawaited(_saveSettings());

    notifyListeners();
  }

  // ===========================================================================
  // LANGUAGE
  // ===========================================================================

  void setLanguage(String lang) {
    if (lang != 'eth' && lang != 'en') {
      return;
    }

    _language = lang;

    unawaited(_saveSettings());

    unawaited(_rescheduleAllReminders());

    notifyListeners();
  }

  // ===========================================================================
  // VIBRATION
  // ===========================================================================

  void toggleVibration(bool value) {
    _vibrationEnabled = value;

    unawaited(_saveSettings());

    unawaited(_rescheduleAllReminders());

    notifyListeners();
  }

  // ===========================================================================
  // SOUND
  // ===========================================================================

  void toggleNotificationSound(bool value) {
    _notificationSoundEnabled = value;

    unawaited(_saveSettings());

    unawaited(_rescheduleAllReminders());

    notifyListeners();
  }

  // ===========================================================================
  // ONBOARDING
  // ===========================================================================

  void setOnboardingComplete(bool value) {
    _onboardingComplete = value;

    unawaited(_saveSettings());

    notifyListeners();
  }

  // ===========================================================================
  // INDIVIDUAL PRAYER REMINDER
  // ===========================================================================

  void toggleReminder(int index) {
    if (index < 0 || index >= _reminderEnabled.length) {
      return;
    }

    _reminderEnabled[index] = !_reminderEnabled[index];

    unawaited(_saveSettings());

    unawaited(reconcilePrayerReminders());

    notifyListeners();
  }

  // ===========================================================================
  // MASTER REMINDER TOGGLE
  // ===========================================================================

  Future<void> toggleAllReminders(bool value) {
    return value ? enableAllPrayerReminders() : disableAllPrayerReminders();
  }

  Future<void> enableAllPrayerReminders() async {
    try {
      final granted = await NotificationService.requestPermission(
        requestExactAlarms: true,
      );

      if (!granted) {
        _remindersEnabled = false;

        _scheduledReminderCount = 0;

        _notificationError = NotificationService.lastError ?? 'Prayer reminders are disabled because notification permission is off.';

        await _saveSettings();

        notifyListeners();

        return;
      }

      _remindersEnabled = true;

      _reminderEnabled = List<bool>.filled(prayerReminders.length, true);

      _notificationError = null;

      await _saveSettings();

      await reconcilePrayerReminders();

      notifyListeners();
    } catch (error) {
      _remindersEnabled = false;

      _notificationError = NotificationService.lastError ?? error.toString();

      await _saveSettings();

      notifyListeners();
    }
  }

  Future<void> disableAllPrayerReminders() async {
    _remindersEnabled = false;

    _reminderEnabled = List<bool>.filled(prayerReminders.length, false);

    await NotificationService.cancelAllPrayerReminders(
      prayerReminders.map((reminder) => reminder.id),
    );

    _scheduledReminderCount = 0;

    _notificationError = null;

    await _saveSettings();

    notifyListeners();
  }

  // ===========================================================================
  // REMINDER OFFSET
  // ===========================================================================

  Future<void> setReminderOffsetMinutes(int minutes) async {
    const allowedOffsets = <int>{0, 5, 10, 15};

    if (!allowedOffsets.contains(minutes)) {
      return;
    }

    _reminderOffsetMinutes = minutes;

    await _saveSettings();

    await reconcilePrayerReminders();

    notifyListeners();
  }

  // ===========================================================================
  // PERMISSION
  // ===========================================================================

  Future<void> requestNotificationPermission() async {
    final granted = await NotificationService.requestPermission();

    if (!granted) {
      _notificationError = NotificationService.lastError ?? 'Prayer reminders are disabled because notification permission is off.';
    } else {
      _notificationError = null;
    }

    notifyListeners();
  }

  Future<void> refreshNotificationPermission() async {
    final granted =
        await NotificationService.refreshNotificationPermissionStatus();

    if (!granted && _remindersEnabled) {
      _remindersEnabled = false;

      _reminderEnabled = List<bool>.filled(prayerReminders.length, false);

      _scheduledReminderCount = 0;

      await NotificationService.cancelAllPrayerReminders(
        prayerReminders.map((reminder) => reminder.id),
      );

      await _saveSettings();
    }

    notifyListeners();
  }

  // ===========================================================================
  // TEST NOTIFICATION
  // ===========================================================================

  Future<bool> sendTestNotification() async {
    if (_testingNotification) {
      return false;
    }

    _testingNotification = true;

    _notificationError = null;

    notifyListeners();

    try {
      final granted = await NotificationService.requestPermission();

      if (!granted) {
        _notificationError =
            NotificationService.lastError ??
            'Allow notifications to send a test reminder.';

        return false;
      }

      final shown = await NotificationService.showTestNotification(
        title: 'የጸሎት ማሳሰቢያ ሙከራ|Prayer reminder test',
        body: 'ማሳሰቢያዎች እንዴት እንደሚሰሙ ለመፈተሽ ነው።|This checks your reminder sound and vibration settings.',
        vibrationEnabled: _vibrationEnabled,
        soundEnabled: _notificationSoundEnabled,
        language: _language,
      );

      _notificationError = shown ? null : NotificationService.lastError;

      return shown;
    } catch (error) {
      _notificationError = NotificationService.lastError ?? error.toString();

      return false;
    } finally {
      _testingNotification = false;

      notifyListeners();
    }
  }

  // ===========================================================================
  // OPEN ANDROID SETTINGS
  // ===========================================================================

  Future<void> openNotificationSettings() async {
    await NotificationService.openNotificationSettings();
  }

  Future<void> openExactAlarmSettings() async {
    await NotificationService.openExactAlarmSettings();
  }

  // ===========================================================================
  // SCHEDULE ONE REMINDER
  // ===========================================================================

  Future<bool> _scheduleReminder(int index) async {
    if (index < 0 || index >= prayerReminders.length) {
      return false;
    }

    final reminder = prayerReminders[index];

    final id = reminder.id;

    // Disabled master toggle or individual prayer.
    if (!_remindersEnabled || !_reminderEnabled[index]) {
      await NotificationService.cancel(id);

      return false;
    }

    try {
      final scheduled = await NotificationService.scheduleDailyReminder(
        id: id,
        title: '${reminder.amharicTitle} ሰዓት|${reminder.englishTitle} Prayer',
        body:
            'የ${reminder.amharicTitle} ሰዓት ጸሎት ጊዜ ነው።|Time for ${reminder.englishTitle} prayer. Rise for prayer!',
        hour: reminder.hour,
        minute: reminder.minute,
        vibrationEnabled: _vibrationEnabled,
        soundEnabled: _notificationSoundEnabled,
        reminderOffset: Duration(minutes: _reminderOffsetMinutes),
        language: _language,
        prayerIndex: index,
      );

      if (!scheduled) {
        _notificationError =
            NotificationService.lastError ??
            'Prayer reminder scheduling is unavailable.';
      } else {
        _notificationError = null;
      }

      return scheduled;
    } catch (error) {
      _notificationError = NotificationService.lastError ?? error.toString();

      return false;
    }
  }

  // ===========================================================================
  // RECONCILE ALL REMINDERS
  // ===========================================================================

  Future<void> reconcilePrayerReminders() {
    _scheduleQueue = _scheduleQueue.catchError((_) {}).then((_) async {
      if (!_remindersEnabled) {
        await NotificationService.cancelAllPrayerReminders();

        _scheduledReminderCount = 0;

        notifyListeners();

        return;
      }

      final permission =
          await NotificationService.refreshNotificationPermissionStatus();

      if (!permission) {
        _remindersEnabled = false;

        _scheduledReminderCount = 0;

        _notificationError = NotificationService.lastError ?? 'Prayer reminders are disabled because notification permission is off.';

        await _saveSettings();

        notifyListeners();

        return;
      }

      var scheduledCount = 0;

      for (int i = 0; i < prayerReminders.length; i++) {
        final success = await _scheduleReminder(i);

        if (success) {
          scheduledCount++;
        }
      }

      _scheduledReminderCount = scheduledCount;

      notifyListeners();
    });

    return _scheduleQueue;
  }

  Future<void> _rescheduleAllReminders() {
    return reconcilePrayerReminders();
  }

  // ===========================================================================
  // SAVE
  // ===========================================================================

  Future<void> _saveSettings() {
    _saveQueue = _saveQueue.then((_) async {
      final prefs = await PreferencesStore.instance.preferences;

      await prefs.setString('themeMode', _themeMode.name);

      await prefs.setString('language', _language);

      await prefs.setBool('vibration', _vibrationEnabled);

      await prefs.setBool('notificationSound', _notificationSoundEnabled);

      await prefs.setBool('remindersEnabled', _remindersEnabled);

      await prefs.setInt('reminderOffsetMinutes', _reminderOffsetMinutes);

      await prefs.setBool('onboardingComplete', _onboardingComplete);

      await prefs.setStringList(
        'reminders',
        _reminderEnabled.map((enabled) => enabled.toString()).toList(),
      );
    });

    return _saveQueue;
  }

  // ===========================================================================
  // LOAD
  // ===========================================================================

  Future<void> _loadSettings() async {
    try {
      final prefs = await PreferencesStore.instance.preferences;

      final savedTheme = prefs.getString('themeMode');

      _themeMode = ThemeModeType.values.firstWhere(
        (e) => e.name == savedTheme,
        orElse: () => ThemeModeType.dark,
      );

      final savedLanguage = prefs.getString('language');

      _language = savedLanguage == 'en' ? 'en' : 'eth';

      _vibrationEnabled = prefs.getBool('vibration') ?? true;

      _notificationSoundEnabled = prefs.getBool('notificationSound') ?? true;

      _remindersEnabled = prefs.getBool('remindersEnabled') ?? false;

      _reminderOffsetMinutes = prefs.getInt('reminderOffsetMinutes') ?? 0;

      _onboardingComplete = prefs.getBool('onboardingComplete') ?? false;

      final reminders = prefs.getStringList('reminders');

      if (reminders != null && reminders.length == prayerReminders.length) {
        _reminderEnabled = reminders.map((value) => value == 'true').toList();
      }

      notifyListeners();

      // Do not block provider construction.
      unawaited(_rescheduleAllReminders());
    } catch (error) {
      _notificationError = 'Could not load saved settings: $error';

      notifyListeners();
    }
  }
}
