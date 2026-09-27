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
        unselectedItemColor: colors.onSurface.withValues(alpha: 0.45),
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

class _HomeTabState extends ConsumerState<_HomeTab> with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _hourKeys = <int, GlobalKey>{
    for (final hour in hours) hour.id: GlobalKey(),
  };
  int? _focusedPrayerId;

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
    final completed = prayers.completedCount;
    final currentPrayer = timeService.currentPrayer;
    _focusCurrentPrayer(currentPrayer.hour.id);

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildHeader(timeService, language, context),
          const SizedBox(height: 16),
          _buildHeroCard(
            completed,
            completed / 7,
            prayers,
            timeService,
            context,
            language,
          ),
          const SizedBox(height: 16),
          _buildDailyScripture(language, context, dailyScripture),
          Card(
            child: ListTile(
              title: Text(localizedText(language, 'የሳምንቱ የጸሎት ሥርዓት', 'Weekly prayer rule')),
              subtitle: Text(localizedText(language, 'መዝሙረ ዳዊት እና የጸሎት ሥርዓት', 'Psalms and the daily prayer order')),
              onTap: () => Navigator.pushNamed(context, '/weekly-prayer-rule'),
            ),
          ),
          const SizedBox(height: 16),
          ...hours.map(
            (hour) => _hourTile(hour, prayers, timeService, context, language),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _focusCurrentPrayer(int prayerId) {
    if (_focusedPrayerId == prayerId) return;
    _focusedPrayerId = prayerId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final itemContext = _hourKeys[prayerId]?.currentContext;
      if (!mounted || itemContext == null) return;
      Scrollable.ensureVisible(
        itemContext,
        alignment: 0.35,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
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
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 13,
                  color: colors.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${localizedText(language, 'ዕለታዊ ጸሎት', 'Daily Prayer')} · ${timeService.formattedTime}',
                style: GoogleFonts.cinzel(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                language == 'eth'
                    ? timeService.formatEthiopianDate(language: language)
                    : timeService.formattedGregorianDate,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colors.primary.withValues(alpha: 0.65),
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
    PrayerProvider prayerProvider,
    TimeService timeService,
    BuildContext context,
    String language,
  ) {
    final colors = Theme.of(context).colorScheme;
    final nextPrayer = timeService.nextPrayer;
    final currentPrayer = timeService.currentPrayer;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.surface,
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            localizedText(language, 'ቀጣዩ የጸሎት ሰዓት', 'Next Prayer Hour'),
            style: GoogleFonts.cinzel(
              fontSize: 10,
              letterSpacing: 2,
              color: colors.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${localizedText(language, 'አሁን', 'Current')}: ${localizedText(language, currentPrayer.hour.eth, currentPrayer.hour.en)}',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: colors.onSurface.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
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
                        Text(
                          nextPrayer.hour.icon,
                          style: const TextStyle(fontSize: 22),
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
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      nextPrayer.hour.time,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeService.nextPrayerCountdown,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: colors.secondary,
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
                    day: DateTime.now().weekday - 1,
                    hour: prayerProvider.nextIncompleteIndex,
                  ),
                ),
              ),
              child: Text(
                localizedText(language, 'ጸሎቱን ጀምር', 'Begin Prayer'),
                style: GoogleFonts.cinzel(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
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
        borderRadius: BorderRadius.circular(12),
        color: colors.surface,
        border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          const GoldDividerSmall(),
          const SizedBox(height: 12),
          if (scripture.loading && scripture.passage == null)
            Text(localizedText(language, 'ቅዱስ መጽሐፍ በመጫን ላይ...', 'Loading Scripture...'))
          else if (scripture.passage != null) ...[
            Text(
              language == 'en'
                  ? scripture.passage!.verses.every(
                      (verse) => verse.englishText != null,
                    )
                      ? scripture.passage!.verses
                            .map((verse) => verse.englishText!)
                            .join('\n')
                      : 'English text is unavailable for this passage because its verse numbering does not match the Amharic source.'
                  : scripture.passage!.verses
                        .map((verse) => verse.amharicText)
                        .join('\n'),
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.8),
                height: 1.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              referenceLabel,
              style: GoogleFonts.cinzel(
                fontSize: 10,
                letterSpacing: 1,
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

    return GestureDetector(
      key: _hourKeys[hour.id],
      onTap: () {
        // The weekly rule follows the device's local weekday. Hour ids in the
        // Hours screen share the same seven-hour order as the rule data, so
        // Prime, Terce, and the other hours open today's corresponding rule.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RuleSessionScreen(
              day: DateTime.now().weekday - 1,
              hour: hour.id,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: current
              ? colors.primary.withValues(alpha: 0.12)
              : done
              ? colors.secondary.withValues(alpha: 0.08)
              : colors.surface,
          border: Border.all(
            color: current
                ? colors.secondary.withValues(alpha: 0.38)
                : done
                ? colors.secondary.withValues(alpha: 0.12)
                : colors.secondary.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizedText(language, hour.ge, hour.en),
                    style: GoogleFonts.notoSansEthiopic(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: done ? colors.secondary : colors.onSurface,
                    ),
                  ),
                  Text(
                    hour.time,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: done
                          ? colors.secondary
                          : colors.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              statusLabel,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                color: colors.secondary,
              ),
            ),
          ],
        ),
      ),
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
