import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/data/prayer_data.dart';
import 'package:rise_for_prayer/data/prayer_reminders.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:rise_for_prayer/providers/settings_provider.dart';
import 'package:rise_for_prayer/utils/colors.dart';
import 'package:rise_for_prayer/utils/localization.dart';
import 'package:rise_for_prayer/widgets/eth_cross.dart';
import 'package:rise_for_prayer/widgets/gold_divider.dart';

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

    return Scaffold(
      backgroundColor: background,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                settings.language == 'eth'
                    ? 'ቅንብሮች'
                    : settings.language == 'en'
                    ? 'Settings'
                    : 'ቅንብሮች / Settings',
                style: GoogleFonts.cinzel(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),

            // Appearance
            _buildSectionHeader(settings.language, 'ገጽታ', 'Appearance'),
            const SizedBox(height: 8),
            _buildThemeSelector(settings),
            const SizedBox(height: 12),
            _buildToggleRow(
              label: localizedText(
                settings.language,
                'የማሳሰቢያ ድምጽ',
                'Notification Sound',
              ),
              eth: '',
              value: settings.notificationSoundEnabled,
              icon: Icons.notifications_active,
              onChanged: settings.toggleNotificationSound,
            ),

            const SizedBox(height: 16),
            const GoldDividerSmall(),
            const SizedBox(height: 16),

            // Language
            _buildSectionHeader(settings.language, 'ቋንቋ', 'Language'),
            const SizedBox(height: 8),
            _buildLanguageSelector(settings),

            const SizedBox(height: 16),
            const GoldDividerSmall(),
            const SizedBox(height: 16),

            // Reminder feedback
            _buildSectionHeader(
              settings.language,
              'ማሳወቂያዎች',
              'Reminder feedback',
            ),
            const SizedBox(height: 8),
            _buildToggleRow(
              label: localizedText(
                settings.language,
                'ንዝረት ማሳወቂያ',
                'Vibration Alerts',
              ),
              eth: '',
              value: settings.vibrationEnabled,
              icon: Icons.vibration,
              onChanged: (v) => settings.toggleVibration(v),
            ),
            const SizedBox(height: 10),
            _buildTestNotificationButton(settings),

            const SizedBox(height: 16),
            const GoldDividerSmall(),
            const SizedBox(height: 16),

            // Prayer Reminders
            _buildSectionHeader(
              settings.language,
              'የጸሎት ማሳሰቢያ',
              'Prayer Reminders',
            ),
            const SizedBox(height: 8),
            _buildRemindersSection(settings),
            if (settings.notificationError != null) ...[
              const SizedBox(height: 8),
              Text(
                _notificationErrorText(
                  settings.notificationError!,
                  settings.language,
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 16),
            const GoldDividerSmall(),
            const SizedBox(height: 16),

            // About
            _buildSectionHeader(settings.language, 'ስለ አፕሊኬሽኑ', 'About'),
            const SizedBox(height: 8),
            _buildAboutCard(settings.language),
          ],
        ),
      ),
    );
  }

  // ============ BUILDERS ============

  Widget _buildHeader() {
    final language = ref.watch(settingsProvider).language;
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colors.primary.withValues(alpha: 0.12),
            ),
            child: Center(child: EthCross(size: 20, opacity: 0.78)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizedText(language, 'ቅንብሮች', 'Settings'),
                style: GoogleFonts.cinzel(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              Text(
                localizedText(language, 'የመተግበሪያ ማስተካከያዎች', 'App preferences'),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: colors.onSurface.withValues(alpha: 0.55),
                ),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            localizedText(language, eth, en),
            style: GoogleFonts.cinzel(
              fontSize: 12,
              letterSpacing: 1.4,
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: colors.primary.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(SettingsProvider settings) {
    final appTheme = Theme.of(context);
    final List<Map<String, dynamic>> themes = [
      {
        'id': 'light',
        'label': localizedText(settings.language, 'ብርሃን', 'Light'),
        'color': const Color(0xFFF8F4EA),
      },
      {
        'id': 'dark',
        'label': localizedText(settings.language, 'ጨለማ', 'Dark'),
        'color': AppColors.obsidian,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: appTheme.colorScheme.surface,
        border: Border.all(
          color: appTheme.colorScheme.primary.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: appTheme.colorScheme.primary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: themes.map((theme) {
          final active = settings.themeMode.name == theme['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  settings.setTheme(theme['id'] as String), // ✅ Cast to String
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: active
                      ? AppColors.gold.withValues(alpha: 0.12)
                      : Colors.transparent,
                  border: Border.all(
                    color: active
                        ? AppColors.gold.withValues(alpha: 0.45)
                        : AppColors.gold.withValues(alpha: 0.12),
                    width: active ? 1.5 : 1,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: theme['color'] as Color,
                        border: Border.all(
                          color: appTheme.colorScheme.primary.withValues(
                            alpha: 0.25,
                          ),
                          width: 2,
                        ),
                      ),
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: appTheme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      theme['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: active
                            ? appTheme.colorScheme.primary
                            : appTheme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required String eth,
    required bool value,
    required IconData icon,
    required Function(bool) onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colors.surface,
        border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cinzel(
                    fontSize: 12,
                    color: colors.onSurface,
                  ),
                ),
                if (eth.isNotEmpty)
                  Text(
                    eth,
                    style: GoogleFonts.notoSansEthiopic(
                      fontSize: 10,
                      color: colors.primary.withValues(alpha: 0.55),
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colors.primary,
            activeTrackColor: colors.primary.withValues(alpha: 0.5),
            inactiveThumbColor: colors.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildTestNotificationButton(SettingsProvider settings) {
    final colors = Theme.of(context).colorScheme;
    final isTesting = settings.testingNotification;

    return Semantics(
      button: true,
      label: localizedText(
        settings.language,
        'የማሳወቂያ ሙከራ፤ አሁን ድምጽን እና ንዝረትን ይፈትሻል',
        'Test notification; checks the current sound and vibration settings',
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: isTesting
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
                            :
                                  localizedText(
                                    settings.language,
                                    'የሙከራ ማሳወቂያ መላክ አልተቻለም።',
                                    'Unable to send a test notification.',
                                  ),
                      ),
                    ),
                  );
                },
          icon: isTesting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                )
              : const Icon(Icons.notifications_active_outlined),
          label: Text(
            localizedText(
              settings.language,
              'ማሳወቂያን ይሞክሩ',
              'Test notification',
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: colors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(SettingsProvider settings) {
    final colors = Theme.of(context).colorScheme;
    final isEnglish = settings.language == 'en';
    final List<Map<String, dynamic>> languages = [
      {
        'id': 'eth',
        'label': isEnglish ? 'Amharic' : 'አማርኛ',
        'sub': isEnglish ? 'Amharic' : 'አማርኛ',
        'flag': '🇪🇹',
      },
      {
        'id': 'en',
        'label': isEnglish ? 'English' : 'እንግሊዝኛ',
        'sub': isEnglish ? 'English' : 'እንግሊዝኛ',
        'flag': '🇬🇧',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.1)),
        color: colors.surface,
      ),
      child: Column(
        children: languages.map((lang) {
          final active = settings.language == lang['id'];
          return GestureDetector(
            onTap: () =>
                settings.setLanguage(lang['id'] as String), // ✅ Cast to String
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.burgundy.withValues(alpha: 0.3)
                    : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.07),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    lang['flag'] as String,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang['label'] as String,
                          style: GoogleFonts.notoSansEthiopic(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? colors.onSurface
                                : colors.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                        Text(
                          lang['sub'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (active)
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 12,
                        color: AppColors.obsidianDark,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRemindersSection(SettingsProvider settings) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.12)),
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Master toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.gold.withValues(alpha: 0.07),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  size: 20,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizedText(
                          settings.language,
                          'ሁሉንም ማሳሰቢያዎች አንቃ',
                          'Enable All Reminders',
                        ),
                        style: GoogleFonts.cinzel(
                          fontSize: 12,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        localizedText(
                          settings.language,
                          'ሁሉንም አንቃ',
                          'Enable every reminder',
                        ),
                        style: GoogleFonts.notoSansEthiopic(
                          fontSize: 10,
                          color: AppColors.gold.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.remindersEnabled,
                  onChanged: (v) => settings.toggleAllReminders(v),
                  activeThumbColor: AppColors.gold,
                  activeTrackColor: AppColors.gold.withValues(alpha: 0.5),
                  inactiveThumbColor: colors.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Icon(
                  settings.notificationPermissionGranted
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 16,
                  color: settings.notificationPermissionGranted
                      ? Colors.greenAccent
                      : AppColors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    localizedText(
                      settings.language,
                      settings.notificationPermissionGranted
                          ? 'ማሳወቂያዎች፦ ተፈቅዷል'
                          : 'ማሳወቂያዎች፦ ፈቃድ ያስፈልጋል',
                      settings.notificationPermissionGranted
                          ? 'Notifications: Allowed'
                          : 'Notifications: Permission required',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: settings.notificationPermissionGranted
                          ? Colors.greenAccent
                          : AppColors.gold,
                    ),
                  ),
                ),
                if (!settings.notificationPermissionGranted)
                  TextButton(
                    onPressed: () => settings.openNotificationSettings(),
                    child: Text(
                      localizedText(settings.language, 'ቅንብሮች', 'Settings'),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    localizedText(
                      settings.language,
                      '${prayerReminders.length} ማሳሰቢያዎች ንቁ ናቸው (${settings.scheduledReminderCount})',
                      '${settings.scheduledReminderCount} / ${prayerReminders.length} reminders active',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                DropdownButton<int>(
                  value: settings.reminderOffsetMinutes,
                  underline: const SizedBox.shrink(),
                  onChanged: settings.remindersEnabled
                      ? (minutes) {
                          if (minutes != null) {
                            settings.setReminderOffsetMinutes(minutes);
                          }
                        }
                      : null,
                  items: [
                    DropdownMenuItem(value: 0, child: Text(localizedText(settings.language, 'በጸሎት ሰዓት', 'At prayer time'))),
                    DropdownMenuItem(value: 5, child: Text(localizedText(settings.language, 'ከ5 ደቂቃ በፊት', '5 min before'))),
                    DropdownMenuItem(value: 10, child: Text(localizedText(settings.language, 'ከ10 ደቂቃ በፊት', '10 min before'))),
                    DropdownMenuItem(value: 15, child: Text(localizedText(settings.language, 'ከ15 ደቂቃ በፊት', '15 min before'))),
                  ],
                ),
              ],
            ),
          ),
          // Individual hour toggles
          ...List.generate(7, (i) {
            final hour = hours[i];
            final enabled = settings.reminderEnabled[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: i < 6
                      ? BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.05),
                        )
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Text(hour.icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              hour.ge,
                              style: GoogleFonts.notoSansEthiopic(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: enabled
                                    ? colors.onSurface
                                    : colors.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hour.en,
                              style: GoogleFonts.cinzel(
                                fontSize: 9,
                                color: enabled
                                    ? AppColors.gold.withValues(alpha: 0.5)
                                    : colors.onSurface.withValues(alpha: 0.25),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          hour.time,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: enabled
                                ? colors.onSurface.withValues(alpha: 0.58)
                                : colors.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (_) => settings.toggleReminder(i),
                    activeThumbColor: AppColors.gold,
                    activeTrackColor: AppColors.gold.withValues(alpha: 0.5),
                    inactiveThumbColor: colors.onSurface.withValues(alpha: 0.2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAboutCard(String language) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: colors.surface,
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const EthCross(size: 16, opacity: 0.8),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedText(language, '\u1208\u1338\u120e\u1275 \u1270\u1290\u1231', 'Rise for Prayer'),
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      localizedText(language, '\u1208\u1338\u120e\u1275 \u1270\u1290\u1231 \xb7 v1.0.0', 'Rise for Prayer \xb7 v1.0.0'),
                      style: GoogleFonts.cinzel(
                        fontSize: 11,
                        color: AppColors.gold.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.gold.withValues(alpha: 0.4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const GoldDividerSmall(),
          const SizedBox(height: 12),
          Text(
            localizedText(language, '"ስለ ጽድቅህ ፍርድ ሰባት ጊዜ በቀን አመሰግንሃለሁ።" — መዝሙረ ዳዊት 119:164', '"Seven times a day I praise You, because of Your righteous judgments." — Psalm 119:164'),
            textAlign: TextAlign.center,
            style: GoogleFonts.ebGaramond(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: colors.onSurface.withValues(alpha: 0.68),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizedText(language, '\u12e8\u12a2\u1275\u12ee\u1335\u12eb \u12a6\u122d\u1276\u12f6\u12ad\u1235 \u1270\u12cb\u1215\u12f6 \u1264\u1270\u12ad\u122d\u1235\u1272\u12eb\u1295 \u12e8\u1338\u120e\u1275 \u1218\u1270\u130d\u1260\u122a\u12eb', 'Ethiopian Orthodox Tewahedo Church Prayer App'),
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: 10,
              letterSpacing: 2,
              color: AppColors.gold.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

String _notificationErrorText(String error, String language) {
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
