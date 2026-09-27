import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/data/prayer_data.dart';
import 'package:rise_for_prayer/models/hour_data.dart';
import 'package:rise_for_prayer/features/prayer_hours/domain/prayer_schedule.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:rise_for_prayer/providers/settings_provider.dart';
import 'package:rise_for_prayer/services/time_service.dart';
import 'package:rise_for_prayer/utils/localization.dart';
import 'package:rise_for_prayer/widgets/metania_counter.dart';
import 'package:rise_for_prayer/features/weekly_prayer_rule/weekly_prayer_rule.dart';

class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key, this.initialIndex});

  final int? initialIndex;

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  late final ScrollController _scrollController;
  double _scrollProgress = 0;
  double _readingWidth = 1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_updateScrollProgress);
  }

  void _updateScrollProgress() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final progress = max == 0 ? 0.0 : _scrollController.offset / max;
    if ((progress - _scrollProgress).abs() < 0.01) return;
    setState(() => _scrollProgress = progress.clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateScrollProgress)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final currentHour = ref.watch(timeServiceProvider).currentPrayer.hour.id;
    final index = args is int ? args : (widget.initialIndex ?? currentHour);
    final hour = hours[index.clamp(0, hours.length - 1)];
    final settings = ref.watch(settingsProvider);
    final timeService = ref.watch(timeServiceProvider);
    final ruleDay = timeService.now.weekday - 1;
    final ruleItem = weeklyPrayerRule[ruleDay][hour.id];
    final completionProvider = ref.watch(prayerProvider);
    final colors = Theme.of(context).colorScheme;
    final background = Theme.of(context).scaffoldBackgroundColor;
    final scheduledStatus = _statusFor(hour.id, timeService);
    final status = completionProvider.completedHours[hour.id]
        ? PrayerStatus.completed
        : scheduledStatus == PrayerStatus.completed
        ? PrayerStatus.missed
        : scheduledStatus;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          localizedText(settings.language, hour.eth, hour.en),
          style: GoogleFonts.cinzel(fontSize: 15),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: localizedText(
              settings.language,
              'የንባብ ቅንብሮች',
              'Reading settings',
            ),
            icon: const Icon(Icons.text_fields),
            onPressed: () => _showReadingSettings(settings),
          ),
        ],
      ),
      bottomNavigationBar: _readingToolbar(
        settings,
        completionProvider.completedHours[hour.id],
        status != PrayerStatus.upcoming,
        () => completionProvider.toggleHour(hour.id),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: _scrollProgress,
            minHeight: 2,
            backgroundColor: Colors.transparent,
            color: colors.primary.withValues(alpha: 0.7),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                controller: _scrollController,
                padding: Theme.of(context).brightness == Brightness.light
                    ? EdgeInsets.fromLTRB(
                        constraints.maxWidth >= 840 ? 32 : 20,
                        16,
                        constraints.maxWidth >= 840 ? 32 : 20,
                        40,
                      )
                    : const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 720 * _readingWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _prayerHero(
                          hour,
                          settings,
                          status,
                          colors,
                          ruleItem.time,
                        ),
                        const SizedBox(height: 22),
                        WeeklyPrayerRuleReading(
                          day: ruleDay,
                          hour: hour.id,
                          language: settings.language,
                        ),
                        const SizedBox(height: 14),
                        MetaniaCounter(
                          prayerHourId: hour.id,
                          enabled: status != PrayerStatus.upcoming,
                        ),
                        const SizedBox(height: 28),
                        _prayerNavigation(index, settings.language),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PrayerStatus _statusFor(int hourId, TimeService timeService) {
    final occurrence = timeService
        .prayerOccurrencesFor(timeService.now)
        .firstWhere((item) => item.prayerHour.readerIndex == hourId);
    return timeService.prayerStatus(occurrence, timeService.now);
  }

  Widget _prayerHero(
    HourData hour,
    SettingsProvider settings,
    PrayerStatus status,
    ColorScheme colors,
    String displayedRuleTime,
  ) {
    final isLightAppearance = colors.brightness == Brightness.light;
    final statusText = switch (status) {
      PrayerStatus.current => localizedText(
        settings.language,
        'አሁን',
        'Current',
      ),
      PrayerStatus.upcoming => localizedText(
        settings.language,
        'ቀጣይ',
        'Upcoming',
      ),
      PrayerStatus.completed => localizedText(
        settings.language,
        'ተጠናቋል',
        'Completed',
      ),
      PrayerStatus.missed => localizedText(settings.language, 'ያመለጠ', 'Missed'),
    };
    return Container(
      width: double.infinity,
      padding: isLightAppearance
          ? const EdgeInsets.all(22)
          : const EdgeInsets.fromLTRB(4, 12, 4, 4),
      decoration: isLightAppearance
          ? BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.primary.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLightAppearance)
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(hour.icon, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    statusText.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          if (isLightAppearance) const SizedBox(height: 18),
          Text(
            localizedText(settings.language, hour.eth, hour.en),
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            localizedText(settings.language, hour.ge, hour.en),
            style: GoogleFonts.ebGaramond(
              fontSize: 18,
              color: colors.onSurface.withValues(alpha: 0.62),
            ),
          ),
          SizedBox(height: isLightAppearance ? 16 : 12),
          Row(
            children: [
              Text(
                displayedRuleTime,
                style: GoogleFonts.inter(fontSize: 13, color: colors.primary),
              ),
              if (!isLightAppearance) ...[
                const SizedBox(width: 12),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ],
            ],
          ),
          if (!isLightAppearance) ...[
            const SizedBox(height: 16),
            Divider(color: colors.primary.withValues(alpha: 0.22)),
          ],
        ],
      ),
    );
  }

  Widget _readingToolbar(
    SettingsProvider settings,
    bool completed,
    bool canComplete,
    VoidCallback onToggleComplete,
  ) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(color: colors.primary.withValues(alpha: 0.12)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: canComplete ? onToggleComplete : null,
              icon: Icon(
                completed ? Icons.check_circle : Icons.circle_outlined,
              ),
              label: Text(
                !canComplete
                    ? localizedText(
                        settings.language,
                        'ጊዜው ሲደርስ ይከፈታል',
                        'Locked until prayer time',
                      )
                    : completed
                    ? localizedText(settings.language, 'ተጠናቋል', 'Completed')
                    : localizedText(settings.language, 'ጸሎቱን አጠናቅቅ', 'Mark complete'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prayerNavigation(int index, String language) {
    final colors = Theme.of(context).colorScheme;
    final previous = (index - 1 + hours.length) % hours.length;
    final next = (index + 1) % hours.length;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ReadingScreen(initialIndex: previous),
              ),
            ),
            child: Text(
              localizedText(language, hours[previous].eth, hours[previous].en),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ReadingScreen(initialIndex: next),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
            ),
            child: Text(
              localizedText(language, hours[next].eth, hours[next].en),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showReadingSettings(SettingsProvider settings) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizedText(
                  settings.language,
                  'የንባብ ቅንብሮች',
                  'Reading settings',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final option in ['eth', 'en'])
                    ChoiceChip(
                      label: Text(option == 'eth' ? 'አማርኛ' : 'English'),
                      selected: settings.language == option,
                      onSelected: (_) => settings.setLanguage(option),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                localizedText(settings.language, 'የንባብ ስፋት', 'Reading width'),
              ),
              SegmentedButton<double>(
                segments: [
                  ButtonSegment(
                    value: 0.82,
                    label: Text(localizedText(settings.language, 'ጠባብ', 'Compact')),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text(
                      localizedText(settings.language, 'ምቹ', 'Comfortable'),
                    ),
                  ),
                ],
                selected: {_readingWidth},
                onSelectionChanged: (value) =>
                    setState(() => _readingWidth = value.first),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
