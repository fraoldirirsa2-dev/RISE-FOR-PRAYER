import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/data/prayer_data.dart';
import 'package:rise_for_prayer/data/prayer_reminders.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:rise_for_prayer/providers/settings_provider.dart';
import 'package:rise_for_prayer/utils/localization.dart';
import 'package:rise_for_prayer/widgets/eth_cross.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(settingsProvider).refreshNotificationPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final background = Theme.of(context).scaffoldBackgroundColor;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: background,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ቅንብሮች',
                    style: GoogleFonts.notoSansEthiopic(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                tooltip: localizedText(settings.language, 'ተመለስ', 'Back'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
      body: SafeArea(
        top: widget.embedded,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              constraints.maxWidth < 400 ? 16 : 20,
              12,
              constraints.maxWidth < 400 ? 16 : 20,
              28,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.embedded) _buildHeader(settings.language),
                    _buildSectionHeader(settings.language, 'ገጽታ', 'Appearance'),
                    const SizedBox(height: 10),
                    _buildThemeSelector(settings),
                    const SizedBox(height: 20),
                    _sectionDivider(context),
                    _buildSectionHeader(settings.language, 'ቋንቋ', 'Language'),
                    const SizedBox(height: 8),
                    _buildLanguageSelector(settings),
                    const SizedBox(height: 20),
                    _sectionDivider(context),
                    _buildSectionHeader(
                      settings.language,
                      'ማሳወቂያዎች',
                      'Notifications',
                    ),
                    const SizedBox(height: 6),
                    _buildPermissionRow(settings),
                    _settingDivider(context),
                    _buildToggleRow(
                      label: localizedText(
                        settings.language,
                        'የማሳሰቢያ ድምጽ',
                        'Notification sound',
                      ),
                      subtitle: localizedText(
                        settings.language,
                        'ለጸሎት ማሳሰቢያዎች ድምጽ አጫውት',
                        'Play sound for prayer reminders',
                      ),
                      value: settings.notificationSoundEnabled,
                      icon: Icons.notifications_active_outlined,
                      onChanged: settings.toggleNotificationSound,
                    ),
                    _settingDivider(context),
                    _buildToggleRow(
                      label: localizedText(
                        settings.language,
                        'ንዝረት',
                        'Vibration',
                      ),
                      subtitle: localizedText(
                        settings.language,
                        'ማሳሰቢያ ሲመጣ ንዝረት አሳይ',
                        'Vibrate when a reminder arrives',
                      ),
                      value: settings.vibrationEnabled,
                      icon: Icons.vibration,
                      onChanged: settings.toggleVibration,
                    ),
                    _settingDivider(context),
                    _buildTestNotificationButton(settings),
                    if (settings.notificationError != null) ...[
                      const SizedBox(height: 8),
                      _buildNotificationError(settings),
                    ],
                    const SizedBox(height: 20),
                    _sectionDivider(context),
                    _buildSectionHeader(
                      settings.language,
                      'የጸሎት ማሳሰቢያ',
                      'Prayer reminders',
                    ),
                    const SizedBox(height: 8),
                    _buildRemindersSection(settings),
                    const SizedBox(height: 20),
                    _sectionDivider(context),
                    _buildSectionHeader(
                      settings.language,
                      'ስለ አፕሊኬሽኑ',
                      'About',
                    ),
                    const SizedBox(height: 8),
                    _buildAboutCard(settings.language),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============ BUILDERS ============

  Widget _buildHeader(String language) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          const EthCross(size: 24, opacity: 0.82),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ቅንብሮች',
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              Text(
                'Settings',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String language, String eth, String en) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        localizedText(language, eth, en),
        style: language == 'eth'
            ? GoogleFonts.notoSansEthiopic(
                fontSize: 16,
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              )
            : GoogleFonts.cinzel(
                fontSize: 15,
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
      ),
    );
  }

  Widget _sectionDivider(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
  );

  Widget _settingDivider(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 48),
    child: Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  );

  Widget _buildThemeSelector(SettingsProvider settings) {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'light',
          icon: const Icon(Icons.light_mode_outlined),
          label: Text(localizedText(settings.language, 'ብርሃን', 'Light')),
        ),
        ButtonSegment(
          value: 'dark',
          icon: const Icon(Icons.dark_mode_outlined),
          label: Text(localizedText(settings.language, 'ጨለማ', 'Dark')),
        ),
      ],
      selected: {settings.themeMode.name},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => settings.setTheme(selection.first),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Function(bool) onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: colors.primary),
      title: Text(label),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeThumbColor: colors.primary,
      activeTrackColor: colors.primary.withValues(alpha: 0.42),
      inactiveThumbColor: colors.onSurface.withValues(alpha: 0.45),
      minTileHeight: 64,
      dense: false,
      visualDensity: VisualDensity.standard,
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  Widget _buildPermissionRow(SettingsProvider settings) {
    final colors = Theme.of(context).colorScheme;
    final allowed = settings.notificationPermissionGranted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            allowed ? Icons.check_circle_outline : Icons.info_outline,
            color: allowed ? colors.primary : colors.secondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localizedText(settings.language, 'ፈቃድ', 'Permission')),
                Text(
                  localizedText(
                    settings.language,
                    allowed ? 'ማሳወቂያዎች ተፈቅደዋል' : 'የማሳወቂያ ፈቃድ ያስፈልጋል',
                    allowed
                        ? 'Notifications allowed'
                        : 'Notification permission required',
                  ),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (!allowed)
            TextButton.icon(
              onPressed: settings.openNotificationSettings,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                localizedText(settings.language, 'ቅንብሮች', 'Open Settings'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationError(SettingsProvider settings) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.error.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: colors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedText(
                    settings.language,
                    'የማሳወቂያ ቅንብር ትኩረት ይፈልጋል',
                    'Notification setup needs attention',
                  ),
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: colors.error),
                ),
                const SizedBox(height: 3),
                Text(
                  _notificationErrorText(
                    settings.notificationError!,
                    settings.language,
                  ),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestNotificationButton(SettingsProvider settings) {
    final colors = Theme.of(context).colorScheme;
    final isTesting = settings.testingNotification;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 10,
      leading: isTesting
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            )
          : Icon(Icons.notifications_active_outlined, color: colors.primary),
      title: Text(
        localizedText(settings.language, 'የሙከራ ማሳወቂያ', 'Test notification'),
      ),
      subtitle: Text(
        localizedText(
          settings.language,
          'የአሁኑን ድምጽና ንዝረት ይፈትሻል',
          'Checks your current sound and vibration settings',
        ),
      ),
      trailing: isTesting
          ? Text(localizedText(settings.language, 'በመሞከር ላይ', 'Testing…'))
          : const Icon(Icons.chevron_right),
      onTap: isTesting
          ? null
          : () async {
              final sent = await settings.sendTestNotification();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    sent
                        ? localizedText(
                            settings.language,
                            'የሙከራ ማሳወቂያ ተልኳል።',
                            'Test notification sent.',
                          )
                        : settings.notificationError != null
                        ? _notificationErrorText(
                            settings.notificationError!,
                            settings.language,
                          )
                        : localizedText(
                            settings.language,
                            'የሙከራ ማሳወቂያ መላክ አልተቻለም።',
                            'Unable to send a test notification.',
                          ),
                  ),
                ),
              );
            },
    );
  }

  Widget _buildLanguageSelector(SettingsProvider settings) {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'eth',
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [Text('አማርኛ'), Text('Amharic')],
          ),
        ),
        ButtonSegment(
          value: 'en',
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [Text('English'), Text('እንግሊዝኛ')],
          ),
        ),
      ],
      selected: {settings.language},
      showSelectedIcon: true,
      onSelectionChanged: (selection) => settings.setLanguage(selection.first),
    );
  }

  Widget _buildRemindersSection(SettingsProvider settings) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToggleRow(
          label: localizedText(
            settings.language,
            'ሁሉንም ማሳሰቢያዎች አንቃ',
            'Enable all reminders',
          ),
          subtitle: localizedText(
            settings.language,
            'ለሰባቱ የጸሎት ሰዓታት ማሳሰቢያ ተቀበል',
            'Receive reminders for your seven prayer hours',
          ),
          value: settings.remindersEnabled,
          icon: Icons.notifications_active_outlined,
          onChanged: (enabled) => settings.toggleAllReminders(enabled),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 48,
            top: 2,
            bottom: 8,
          ),
          child: Text(
            localizedText(
              settings.language,
              '${settings.scheduledReminderCount} / ${prayerReminders.length} ማሳሰቢያዎች ንቁ',
              '${settings.scheduledReminderCount} / ${prayerReminders.length} reminders active',
            ),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        _settingDivider(context),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizedText(settings.language, 'የማሳሰቢያ ጊዜ', 'Reminder time'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 3),
              Text(
                localizedText(
                  settings.language,
                  'ማሳሰቢያው መቼ እንዲመጣ ይምረጡ',
                  'When should the reminder appear?',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: settings.reminderOffsetMinutes,
                isExpanded: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onChanged: (minutes) {
                  if (minutes != null) {
                    settings.setReminderOffsetMinutes(minutes);
                  }
                },
                items: [
                  DropdownMenuItem(
                    value: 0,
                    child: Text(
                      localizedText(
                        settings.language,
                        'በጸሎት ሰዓት',
                        'At prayer time',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 5,
                    child: Text(
                      localizedText(
                        settings.language,
                        'ከ5 ደቂቃ በፊት',
                        '5 minutes before',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 10,
                    child: Text(
                      localizedText(
                        settings.language,
                        'ከ10 ደቂቃ በፊት',
                        '10 minutes before',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 15,
                    child: Text(
                      localizedText(
                        settings.language,
                        'ከ15 ደቂቃ በፊት',
                        '15 minutes before',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          localizedText(settings.language, 'የጸሎት ሰዓታት', 'Prayer hours'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        for (var index = 0; index < hours.length; index++) ...[
          if (index > 0) _settingDivider(context),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 68,
            secondary: Icon(
              Icons.schedule_outlined,
              color: settings.remindersEnabled
                  ? colors.primary
                  : colors.onSurfaceVariant,
            ),
            title: Text(
              hours[index].ge,
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${hours[index].en} · ${hours[index].time}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: settings.reminderEnabled[index],
            onChanged: settings.remindersEnabled
                ? (_) => settings.toggleReminder(index)
                : null,
          ),
        ],
      ],
    );
  }

  Widget _buildAboutCard(String language) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const EthCross(size: 22, opacity: 0.82),
          const SizedBox(height: 10),
          Text(
            localizedText(
              language,
              '\u1208\u1338\u120e\u1275 \u1270\u1290\u1231',
              'Rise for Prayer',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          Text(
            localizedText(
              language,
              '\u1208\u1338\u120e\u1275 \u1270\u1290\u1231 \xb7 v1.0.0',
              'Rise for Prayer \xb7 v1.0.0',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Text(
            localizedText(
              language,
              '"ስለ ጽድቅህ ፍርድ ሰባት ጊዜ በቀን አመሰግንሃለሁ።" — መዝሙረ ዳዊት 119:164',
              '"Seven times a day I praise You, because of Your righteous judgments." — Psalm 119:164',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.ebGaramond(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: colors.onSurface.withValues(alpha: 0.68),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizedText(
              language,
              '\u12e8\u12a2\u1275\u12ee\u1335\u12eb \u12a6\u122d\u1276\u12f6\u12ad\u1235 \u1270\u12cb\u1215\u12f6 \u1264\u1270\u12ad\u122d\u1235\u1272\u12eb\u1295 \u12e8\u1338\u120e\u1275 \u1218\u1270\u130d\u1260\u122a\u12eb',
              'Ethiopian Orthodox Tewahedo Church Prayer App',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String _notificationErrorText(String error, String language) {
  if (error.length > 180 ||
      error.contains('PlatformException') ||
      error.contains('Missing type parameter') ||
      error.contains('r8-map-id')) {
    return localizedText(
      language,
      'የማሳሰቢያ ቅንብር አልተሳካም። አፕሊኬሽኑን ዝግተው እንደገና ይክፈቱ።',
      'Reminder setup failed. Close and reopen the app, then try again.',
    );
  }
  if (language == 'en') return error;
  if (error.contains('permission')) {
    return 'የማሳወቂያ ፈቃድ ስላልተሰጠ ማሳሰቢያዎች ተዘግተዋል።';
  }
  if (error.contains('Allow notifications')) {
    return 'የሙከራ ማሳሰቢያ ለመላክ ማሳወቂያዎችን ይፍቀዱ።';
  }
  if (error.contains('test notification')) {
    return 'የሙከራ ማሳወቂያ መላክ አልተቻለም።';
  }
  return 'ማሳወቂያውን መላክ አልተቻለም።';
}
