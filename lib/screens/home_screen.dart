import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/data/prayer_data.dart';
import 'package:rise_for_prayer/features/analysis/screens/analysis_screen.dart';
import 'package:rise_for_prayer/features/prayer_hours/domain/prayer_schedule.dart';
import 'package:rise_for_prayer/features/bible/providers/daily_scripture_provider.dart';
import 'package:rise_for_prayer/features/bible/repositories/bible_repository.dart';
import 'package:rise_for_prayer/features/weekly_prayer_rule/weekly_prayer_rule.dart';
import 'package:rise_for_prayer/models/hour_data.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:rise_for_prayer/providers/prayer_provider.dart';
import 'package:rise_for_prayer/screens/calendar_screen.dart';
import 'package:rise_for_prayer/screens/settings_screen.dart';
import 'package:rise_for_prayer/services/time_service.dart';
import 'package:rise_for_prayer/utils/localization.dart';
import 'package:rise_for_prayer/widgets/eth_cross.dart';
import 'package:rise_for_prayer/widgets/gold_divider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = const [
    _HomeTab(),
    _AnalysisTab(),
    _CalendarTab(),
    _SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(settingsProvider).language;
    final colors = Theme.of(context).colorScheme;
    final background = Theme.of(context).scaffoldBackgroundColor;
    String label(String english, String amharic) =>
        localizedText(language, amharic, english);

    return Scaffold(
      backgroundColor: background,
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: background,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.onSurface.withValues(alpha: 0.68),
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.schedule_outlined),
            label: label('Hours', 'ሰዓታት'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart_outlined),
            label: label('Analysis', 'ትንተና'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_month_outlined),
            label: label('Calendar', 'የቀን መቁጠሪያ'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            label: label('Settings', 'ቅንብሮች'),
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerStatefulWidget {
  const _HomeTab();

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(dailyScriptureProvider).loadDaily();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prayers = ref.watch(prayerProvider);
    final language = ref.watch(settingsProvider).language;
    final dailyScripture = ref.watch(dailyScriptureProvider);
    final timeService = ref.watch(timeServiceProvider);

    return SafeArea(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(timeService, language, context),
                const SizedBox(height: 20),
                _buildHeroCard(
                  prayers.completedCount,
                  prayers.completedCount / 7,
                  timeService,
                  context,
                  language,
                ),
                const SizedBox(height: 20),
                _buildDailyScripture(language, context, dailyScripture),
                const SizedBox(height: 28),
                Text(
                  localizedText(language, 'የጸሎት ሰዓታት', 'Prayer Hours'),
                  style: language == 'eth'
                      ? GoogleFonts.notoSansEthiopic(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        )
                      : GoogleFonts.cinzel(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                ),
                const SizedBox(height: 8),
                ...hours.map(
                  (hour) =>
                      _hourTile(hour, prayers, timeService, context, language),
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.menu_book_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      localizedText(
                        language,
                        'የሳምንቱ የጸሎት ሥርዓት',
                        'Weekly prayer rule',
                      ),
                    ),
                    subtitle: Text(
                      localizedText(
                        language,
                        'መዝሙረ ዳዊት እና የጸሎት ሥርዓት',
                        'Psalms and the daily prayer order',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.pushNamed(context, '/weekly-prayer-rule'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PrayerStatus _statusForHour(TimeService timeService, int hourId) {
    final now = timeService.now;
    final statusDate = hourId == 6 && timeService.currentPrayer.hour.id != 6
        ? now.add(const Duration(days: 1))
        : now;
    final occurrence = timeService
        .prayerOccurrencesFor(statusDate)
        .firstWhere((item) => item.prayerHour.readerIndex == hourId);
    return timeService.prayerStatus(occurrence, now);
  }

  Widget _buildHeader(
    TimeService timeService,
    String language,
    BuildContext context,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizedText(language, 'ሰላም ይሁንልዎ', 'Peace be with you'),
                style: language == 'eth'
                    ? GoogleFonts.notoSansEthiopic(
                        fontSize: 14,
                        color: colors.primary.withValues(alpha: 0.82),
                      )
                    : GoogleFonts.ebGaramond(
                        fontSize: 16,
                        color: colors.primary.withValues(alpha: 0.82),
                      ),
              ),
              const SizedBox(height: 2),
              Text(
                '${localizedText(language, 'ዕለታዊ ጸሎት', 'Daily Prayer')} · ${timeService.formattedTime}',
                style: language == 'eth'
                    ? GoogleFonts.notoSansEthiopic(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      )
                    : GoogleFonts.cinzel(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
              ),
              const SizedBox(height: 3),
              Text(
                language == 'eth'
                    ? timeService.formatEthiopianDate(language: language)
                    : timeService.formattedGregorianDate,
                style: language == 'eth'
                    ? GoogleFonts.notoSansEthiopic(
                        fontSize: 13,
                        color: colors.onSurface.withValues(alpha: 0.72),
                      )
                    : GoogleFonts.inter(
                        fontSize: 13,
                        color: colors.onSurface.withValues(alpha: 0.72),
                      ),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colors.secondary.withValues(alpha: 0.18),
            border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
          ),
          child: const Center(child: EthCross(size: 20, opacity: 0.8)),
        ),
      ],
    );
  }

  Widget _buildHeroCard(
    int completed,
    double progress,
    TimeService timeService,
    BuildContext context,
    String language,
  ) {
    final colors = Theme.of(context).colorScheme;
    final nextPrayer = timeService.nextPrayer;
    final currentPrayer = timeService.currentPrayer;
    final now = timeService.now;
    final startsTomorrow =
        nextPrayer.dateTime.year != now.year ||
        nextPrayer.dateTime.month != now.month ||
        nextPrayer.dateTime.day != now.day;
    final scheduledDay = localizedText(
      language,
      startsTomorrow ? 'ነገ' : 'ዛሬ',
      startsTomorrow ? 'Tomorrow' : 'Today',
    );
    final countdown = timeService.nextPrayerCountdown;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.surface,
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            localizedText(language, 'ቀጣዩ የጸሎት ሰዓት', 'Next Prayer Hour'),
            style: language == 'eth'
                ? GoogleFonts.notoSansEthiopic(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.secondary,
                  )
                : GoogleFonts.cinzel(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.secondary,
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            '${localizedText(language, 'አሁን', 'Current')}: ${localizedText(language, currentPrayer.hour.eth, currentPrayer.hour.en)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.76),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Semantics(
                excludeSemantics: true,
                label: localizedText(
                  language,
                  'ከ7 የጸሎት ሰዓታት ውስጥ $completed ተጠናቋል',
                  '$completed of 7 prayer hours completed',
                ),
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(120, 120),
                        painter: _ProgressPainter(
                          progress: progress,
                          color: colors.secondary,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 24,
                            color: colors.secondary,
                          ),
                          Text(
                            '$completed/7',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedText(
                        language,
                        nextPrayer.hour.eth,
                        nextPrayer.hour.en,
                      ),
                      style: language == 'eth'
                          ? GoogleFonts.notoSansEthiopic(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            )
                          : GoogleFonts.ebGaramond(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$scheduledDay · ${nextPrayer.hour.time}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colors.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizedText(language, 'የሚቀረው ጊዜ', 'Starts in'),
                      style: language == 'eth'
                          ? GoogleFonts.notoSansEthiopic(
                              fontSize: 13,
                              color: colors.onSurface.withValues(alpha: 0.76),
                            )
                          : GoogleFonts.inter(
                              fontSize: 13,
                              color: colors.onSurface.withValues(alpha: 0.76),
                            ),
                    ),
                    Semantics(
                      label: localizedText(
                        language,
                        'ቀጣዩ ጸሎት በ$countdown ይጀምራል',
                        'Next prayer starts in $countdown',
                      ),
                      child: Text(
                        countdown,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: colors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RuleSessionScreen(
                    day: nextPrayer.dateTime.weekday - 1,
                    hour: nextPrayer.hour.id,
                  ),
                ),
              ),
              child: Text(
                localizedText(language, 'ቀጣዩን ጸሎት ይመልከቱ', 'View Next Prayer'),
                style: language == 'eth'
                    ? GoogleFonts.notoSansEthiopic(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      )
                    : GoogleFonts.cinzel(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyScripture(
    String language,
    BuildContext context,
    DailyScriptureProvider scripture,
  ) {
    final colors = Theme.of(context).colorScheme;
    final reference = scripture.passage?.reference;
    final referenceLabel = reference == null
        ? localizedText(language, 'መጽሐፍ ቅዱስ', 'Bible')
        : language == 'en'
        ? '${englishBibleBookName(reference.bookId)} ${reference.chapter}:'
              '${reference.startVerse ?? 1}'
              '${reference.endVerse == null || reference.endVerse == reference.startVerse ? '' : '-${reference.endVerse}'}'
        : reference.label ?? localizedText(language, 'መጽሐፍ ቅዱስ', 'Bible');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: colors.surface,
        border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizedText(language, 'የዕለቱ ቅዱስ ቃል', 'Daily Scripture'),
            style: language == 'eth'
                ? GoogleFonts.notoSansEthiopic(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  )
                : GoogleFonts.cinzel(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
          ),
          const SizedBox(height: 10),
          const GoldDividerSmall(),
          const SizedBox(height: 12),
          if (scripture.loading && scripture.passage == null)
            Text(
              localizedText(
                language,
                'ቅዱስ መጽሐፍ በመጫን ላይ...',
                'Loading Scripture...',
              ),
            )
          else if (scripture.passage != null) ...[
            Text(
              language == 'en'
                  ? scripture.passage!.verses.every(
                          (verse) => verse.englishText != null,
                        )
                        ? scripture.passage!.verses
                              .map((verse) => verse.englishText!)
                              .join('\n')
                        : 'English text is unavailable for this passage.'
                  : scripture.passage!.verses
                        .map((verse) => verse.amharicText)
                        .join('\n'),
              textAlign: TextAlign.start,
              style: language == 'eth'
                  ? GoogleFonts.notoSansEthiopic(
                      fontSize: 17,
                      color: colors.onSurface.withValues(alpha: 0.9),
                      height: 1.9,
                    )
                  : GoogleFonts.ebGaramond(
                      fontSize: 19,
                      color: colors.onSurface.withValues(alpha: 0.9),
                      height: 1.65,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              referenceLabel,
              style: language == 'eth'
                  ? GoogleFonts.notoSansEthiopic(
                      fontSize: 13,
                      color: colors.secondary,
                    )
                  : GoogleFonts.ebGaramond(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.secondary,
                    ),
            ),
          ] else
            Text(
              language == 'eth'
                  ? 'ቅዱስ መጽሐፍ አሁን ማግኘት አልተቻለም።'
                  : scripture.error ?? 'Scripture is currently unavailable.',
            ),
        ],
      ),
    );
  }

  Widget _hourTile(
    HourData hour,
    PrayerProvider provider,
    TimeService timeService,
    BuildContext context,
    String language,
  ) {
    final done = provider.completedHours[hour.id];
    final scheduledStatus = _statusForHour(timeService, hour.id);
    final status = done
        ? PrayerStatus.completed
        : scheduledStatus == PrayerStatus.completed
        ? PrayerStatus.missed
        : scheduledStatus;
    final current = status == PrayerStatus.current;
    final colors = Theme.of(context).colorScheme;
    final statusLabel = switch (status) {
      PrayerStatus.current => localizedText(language, 'አሁን', 'CURRENT'),
      PrayerStatus.upcoming => localizedText(language, 'ቀጣይ', 'UPCOMING'),
      PrayerStatus.completed => localizedText(language, 'ተጠናቋል', 'COMPLETED'),
      PrayerStatus.missed => localizedText(language, 'ያመለጠ', 'MISSED'),
    };

    return Column(
      children: [
        Material(
          color: current
              ? colors.primary.withValues(alpha: 0.08)
              : done
              ? colors.secondary.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RuleSessionScreen(
                  day: DateTime.now().weekday - 1,
                  hour: hour.id,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizedText(language, hour.ge, hour.en),
                          style: language == 'eth'
                              ? GoogleFonts.notoSansEthiopic(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                )
                              : GoogleFonts.ebGaramond(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hour.time,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: colors.onSurface.withValues(alpha: 0.74),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w600,
                      color: colors.secondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colors.onSurface.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(
          height: 1,
          indent: 14,
          endIndent: 14,
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ],
    );
  }
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 54.0;
    final center = Offset(size.width / 2, size.height / 2);
    final background = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, background);
    final foreground = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      progress * 2 * 3.14159,
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CalendarTab extends StatelessWidget {
  const _CalendarTab();

  @override
  Widget build(BuildContext context) => const CalendarScreen(embedded: true);
}

class _AnalysisTab extends StatelessWidget {
  const _AnalysisTab();

  @override
  Widget build(BuildContext context) => const AnalysisScreen();
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) => const SettingsScreen(embedded: true);
}
