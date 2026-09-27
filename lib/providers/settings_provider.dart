import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rise_for_prayer/data/prayer_reminders.dart';
import 'package:rise_for_prayer/services/notification_service.dart';
import 'package:rise_for_prayer/services/preferences_store.dart';

enum ThemeModeType { light, dark }

class SettingsProvider extends ChangeNotifier {
  ThemeModeType _themeMode = ThemeModeType.dark;
  String _language = 'en';
  String? _notificationError;
  bool _vibrationEnabled = true;
  bool _notificationSoundEnabled = true;
  bool _remindersEnabled = false;
  int _reminderOffsetMinutes = 0;
  int _scheduledReminderCount = 0;
  bool _onboardingComplete = false;
  bool _testingNotification = false;
  List<bool> _reminderEnabled = List.filled(7, true);
  Future<void> _saveQueue = Future<void>.value();
  Future<void> _scheduleQueue = Future<void>.value();

  SettingsProvider() {
    _loadSettings();
  }

  ThemeModeType get themeMode => _themeMode;
  String get language => _language;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get notificationSoundEnabled => _notificationSoundEnabled;
  bool get remindersEnabled => _remindersEnabled;
  int get reminderOffsetMinutes => _reminderOffsetMinutes;
  int get scheduledReminderCount => _scheduledReminderCount;
  bool get notificationPermissionGranted =>
      NotificationService.isAvailable;
  String? get notificationError => _notificationError;
  bool get onboardingComplete => _onboardingComplete;
  bool get testingNotification => _testingNotification;
  List<bool> get reminderEnabled => _reminderEnabled;

  ThemeMode get materialThemeMode {
    return _themeMode == ThemeModeType.light ? ThemeMode.light : ThemeMode.dark;
  }

  void setTheme(String mode) {
    _themeMode = ThemeModeType.values.firstWhere(
      (e) => e.name == mode,
      orElse: () => ThemeModeType.dark,
    );
    _saveSettings();
    notifyListeners();
  }

  void setLanguage(String lang) {
    if (lang != 'eth' && lang != 'en') return;
    _language = lang;
    _saveSettings();
    unawaited(_rescheduleAllReminders());
    notifyListeners();
  }

  void toggleVibration(bool value) {
    _vibrationEnabled = value;
    _saveSettings();
    unawaited(_rescheduleAllReminders());
    notifyListeners();
  }

  void toggleNotificationSound(bool value) {
    _notificationSoundEnabled = value;
    unawaited(_saveSettings());
    unawaited(_rescheduleAllReminders());
    notifyListeners();
  }

  void setOnboardingComplete(bool value) {
    _onboardingComplete = value;
    _saveSettings();
    notifyListeners();
  }

  void toggleReminder(int index) {
    if (index < 0 || index >= _reminderEnabled.length) return;
    _reminderEnabled[index] = !_reminderEnabled[index];
    _saveSettings();
    unawaited(reconcilePrayerReminders());
    notifyListeners();
  }

  /// The master toggle is intentionally not a visual preference: enabling it
  /// turns on and reconciles every canonical hour, disabling it cancels all.
  Future<void> toggleAllReminders(bool value) =>
      value ? enableAllPrayerReminders() : disableAllPrayerReminders();

  Future<void> enableAllPrayerReminders() async {
    final granted = await NotificationService.requestPermission();
    if (!granted) {
      _remindersEnabled = false;
      _scheduledReminderCount = 0;
      _notificationError = NotificationService.lastError ??
          'Prayer reminders are disabled because notification permission is off.';
      await _saveSettings();
      notifyListeners();
      return;
    }
    _remindersEnabled = true;
    _reminderEnabled = List<bool>.filled(prayerReminders.length, true);
    await _saveSettings();
    await reconcilePrayerReminders();
    notifyListeners();
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

  Future<void> setReminderOffsetMinutes(int minutes) async {
    const allowedOffsets = <int>{0, 5, 10, 15};
    if (!allowedOffsets.contains(minutes)) return;
    _reminderOffsetMinutes = minutes;
    await _saveSettings();
    await reconcilePrayerReminders();
    notifyListeners();
  }

  Future<void> requestNotificationPermission() async {
    final granted = await NotificationService.requestPermission();
    if (!granted) {
      _notificationError = 'Prayer reminders are disabled because notification permission is off.';
    } else {
      _notificationError = null;
    }
    notifyListeners();
  }

  /// Sends an immediate notification using the feedback preferences currently
  /// selected in Settings. This never changes the canonical reminder schedule.
  Future<bool> sendTestNotification() async {
    if (_testingNotification) return false;
    _testingNotification = true;
    _notificationError = null;
    notifyListeners();

    try {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        _notificationError = NotificationService.lastError ??
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
    } catch (_) {
      _notificationError =
          NotificationService.lastError ??
          'Unable to send a test notification.';
      return false;
    } finally {
      _testingNotification = false;
      notifyListeners();
    }
  }

  Future<void> openNotificationSettings() async {
    await NotificationService.openNotificationSettings();
  }

  Future<void> refreshNotificationPermission() async {
    final granted = await NotificationService.refreshPermissionStatus();
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

  Future<bool> _scheduleReminder(int index) async {
    final reminder = prayerReminders[index];
    final id = reminder.id;

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
      _notificationError = NotificationService.lastError;
      return scheduled;
    } catch (_) {
      // A denied permission or platform scheduling failure must not poison
      // the queue or crash the settings screen.
      _notificationError =
          NotificationService.lastError ??
          'Prayer reminder scheduling is unavailable.';
      return false;
    }
  }

  /// Makes platform schedules exactly match saved preferences. All callers
  /// route through this method so updates cannot leave stale reminders behind.
  Future<void> reconcilePrayerReminders() async {
    _scheduleQueue = _scheduleQueue.catchError((_) {}).then((_) async {
      if (!_remindersEnabled) {
        await NotificationService.cancelAllPrayerReminders(
          prayerReminders.map((reminder) => reminder.id),
        );
        _scheduledReminderCount = 0;
        return;
      }
      if (!await NotificationService.refreshPermissionStatus()) {
        _remindersEnabled = false;
        _scheduledReminderCount = 0;
        _notificationError = 'Prayer reminders are disabled because notification permission is off.';
        await _saveSettings();
        return;
      }
      var scheduledCount = 0;
      for (int i = 0; i < prayerReminders.length; i++) {
        if (await _scheduleReminder(i)) scheduledCount++;
      }
      _scheduledReminderCount = scheduledCount;
      notifyListeners();
    });
    return _scheduleQueue;
  }

  Future<void> _rescheduleAllReminders() => reconcilePrayerReminders();

  Future<void> _saveSettings() async {
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
        _reminderEnabled.map((e) => e.toString()).toList(),
      );
    });
    return _saveQueue;
  }

  Future<void> _loadSettings() async {
    final prefs = await PreferencesStore.instance.preferences;
    _themeMode = ThemeModeType.values.firstWhere(
      (e) => e.name == prefs.getString('themeMode'),
      orElse: () => ThemeModeType.dark,
    );
    final savedLanguage = prefs.getString('language');
    _language = savedLanguage == 'eth' ? 'eth' : 'en';
    _vibrationEnabled = prefs.getBool('vibration') ?? true;
    _notificationSoundEnabled = prefs.getBool('notificationSound') ?? true;
    _remindersEnabled = prefs.getBool('remindersEnabled') ?? false;
    _reminderOffsetMinutes = prefs.getInt('reminderOffsetMinutes') ?? 0;
    _onboardingComplete = prefs.getBool('onboardingComplete') ?? false;

    final reminders = prefs.getStringList('reminders');
    if (reminders != null && reminders.length == 7) {
      _reminderEnabled = reminders.map((e) => e == 'true').toList();
    }

    unawaited(_rescheduleAllReminders());
    notifyListeners();
  }
}
