import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/data/prayer_data.dart';
import 'package:rise_for_prayer/features/analysis/models/analysis_models.dart';
import 'package:rise_for_prayer/features/analysis/providers/analysis_provider.dart';
import 'package:rise_for_prayer/providers/prayer_provider.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:rise_for_prayer/utils/localization.dart';
import 'package:rise_for_prayer/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(analysisProvider);
    final prayer = ref.watch(prayerProvider);
    final language = ref.watch(settingsProvider).language;
    final summary = analysis.summary;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('የጸሎት ትንተና', style: Theme.of(context).textTheme.titleMedium),
            Text(
              'Prayer Analysis',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RangeSelector(
                      analysis: analysis,
                      prayer: prayer,
                      language: language,
                    ),
                    const SizedBox(height: 16),
                    if (!summary.hasHistory ||
                        summary.dailyStatistics.isEmpty) ...[
                      _EmptyAnalysisState(language: language),
                      const SizedBox(height: 16),
                    ] else ...[
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _TodayPrayerJourney(
                                completedHours: prayer.completedHours,
                                language: language,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: _SupportingMetrics(
                                summary: summary,
                                language: language,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _TodayPrayerJourney(
                          completedHours: prayer.completedHours,
                          language: language,
                        ),
                        const SizedBox(height: 14),
                        _SupportingMetrics(
                          summary: summary,
                          language: language,
                        ),
                      ],
                      const SizedBox(height: 20),
                      _WeeklyChart(summary: summary, language: language),
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _PerformanceCard(
                                summary: summary,
                                language: language,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _StreakCard(
                                summary: summary,
                                language: language,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _PerformanceCard(summary: summary, language: language),
                        const SizedBox(height: 16),
                        _StreakCard(summary: summary, language: language),
                      ],
                    ],
                    const SizedBox(height: 16),
                    _MetaniaAnalysis(
                      rangeDays: analysis.rangeDays,
                      language: language,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.analysis,
    required this.prayer,
    required this.language,
  });

  final AnalysisProvider analysis;
  final PrayerProvider prayer;
  final String language;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: [
        ButtonSegment(
          value: 7,
          label: Text(localizedText(language, '7 ቀን', '7D')),
        ),
        ButtonSegment(
          value: 30,
          label: Text(localizedText(language, '30 ቀን', '30D')),
        ),
        ButtonSegment(
          value: 90,
          label: Text(localizedText(language, '3 ወር', '3M')),
        ),
        ButtonSegment(
          value: 365,
          label: Text(localizedText(language, '1 ዓመት', '1Y')),
        ),
      ],
      selected: {analysis.rangeDays},
      onSelectionChanged: (selection) =>
          analysis.setRange(selection.first, prayer),
    );
  }
}

class _EmptyAnalysisState extends StatelessWidget {
  const _EmptyAnalysisState({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.self_improvement, size: 34, color: colors.secondary),
          const SizedBox(height: 12),
          Text(
            localizedText(
              language,
              'የጸሎት ታሪክ እየተጠራ ነው',
              'No prayer history yet',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            localizedText(
              language,
              'የጸሎት ሰዓቶችን ሲያጠናቅቁ የጸሎት ታሪክዎ እዚህ ይታያል።',
              'Prayer history will appear here as you complete prayer hours.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

const _prayerHourNamesAmharic = [
  'ነግህ',
  'ሠለስት',
  'ቀትር',
  'ተሰዓት',
  'ሠርክ',
  'ንዋም',
  'መንፈቀ ሌሊት',
];

class _TodayPrayerJourney extends StatelessWidget {
  const _TodayPrayerJourney({
    required this.completedHours,
    required this.language,
  });

  final List<bool> completedHours;
  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final completed = completedHours.where((value) => value).length;
    final rate = completed / 7;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizedText(language, 'የዛሬ የጸሎት ጉዞ', "Today's Prayer Journey"),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$completed / 7',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _percent(rate),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: localizedText(
              language,
              'ከ7 የጸሎት ሰዓታት ውስጥ $completed ተጠናቋል፣ ${_percent(rate)}',
              '$completed of 7 prayer hours completed, ${_percent(rate)}',
            ),
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: rate,
                  minHeight: 10,
                  color: colors.primary,
                  backgroundColor: colors.onPrimaryContainer.withValues(
                    alpha: 0.12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 7
                  : constraints.maxWidth >= 560
                  ? 4
                  : 2;
              final gap = 8.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < 7; index++)
                    SizedBox(
                      width: width,
                      child: _PrayerHourStatus(
                        index: index,
                        completed:
                            index < completedHours.length &&
                            completedHours[index],
                        language: language,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PrayerHourStatus extends StatelessWidget {
  const _PrayerHourStatus({
    required this.index,
    required this.completed,
    required this.language,
  });

  final int index;
  final bool completed;
  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hourName = localizedText(
      language,
      _prayerHourNamesAmharic[index],
      hours[index].en,
    );
    final state = localizedText(
      language,
      completed ? 'ተጠናቋል' : 'አልተጠናቀቀም',
      completed ? 'Completed' : 'Not completed',
    );
    return Semantics(
      label: '$hourName, $state',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(
              completed ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: completed
                  ? colors.primary
                  : colors.onPrimaryContainer.withValues(alpha: 0.58),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                hourName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportingMetrics extends StatelessWidget {
  const _SupportingMetrics({required this.summary, required this.language});

  final PrayerAnalysisSummary summary;
  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final metrics = [
      (
        localizedText(language, 'የጸሎት መጠን', 'Completion rate'),
        _percent(summary.completionRate),
        localizedText(
          language,
          '${summary.totalCompleted} ከ ${summary.totalExpected} የተጠናቀቁ',
          '${summary.totalCompleted} completed of ${summary.totalExpected}',
        ),
      ),
      (
        localizedText(language, 'የአሁኑ ተከታታይ ጊዜ', 'Current streak'),
        '${summary.currentStreak}',
        localizedText(language, 'ቀናት', 'days'),
      ),
      (
        localizedText(language, 'ምርጥ ተከታታይ ጊዜ', 'Best streak'),
        '${summary.bestStreak}',
        localizedText(language, 'ቀናት', 'days'),
      ),
    ];
    final stackMetrics =
        MediaQuery.sizeOf(context).width < 1120 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    Widget metric(int index, {required bool compact}) {
      final label = Text(
        metrics[index].$1,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: colors.onSurface.withValues(alpha: 0.76)),
      );
      final value = Text(
        metrics[index].$2,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: colors.onSurface, fontWeight: FontWeight.w700),
      );
      final detail = Text(
        metrics[index].$3,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      );
      if (compact) {
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [label, detail],
              ),
            ),
            const SizedBox(width: 12),
            value,
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [label, const SizedBox(height: 3), value, detail],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: stackMetrics
          ? Column(
              children: [
                for (var index = 0; index < metrics.length; index++) ...[
                  if (index > 0)
                    Divider(height: 18, color: colors.outlineVariant),
                  metric(index, compact: true),
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < metrics.length; index++) ...[
                  if (index > 0)
                    SizedBox(
                      height: 56,
                      child: VerticalDivider(
                        width: 1,
                        color: colors.outlineVariant,
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: metric(index, compact: false),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.summary, required this.language});

  final PrayerAnalysisSummary summary;
  final String language;

  @override
  Widget build(BuildContext context) {
    final buckets = _chartBuckets(summary.dailyStatistics);
    final colors = Theme.of(context).colorScheme;
    return _Panel(
      title: localizedText(language, 'እድገት በጊዜ', 'Prayer Completion Trend'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localizedText(
              language,
              'አሞሌዎቹ በጊዜ ክፍሎች የተጠናቀቁ ጸሎቶችን መጠን ያነጻጽራሉ፤ ወርቃማው የመጨረሻውን ጊዜ ያመለክታል።',
              'Bars compare completion rates across the selected period; gold marks the latest interval.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%', style: Theme.of(context).textTheme.labelSmall),
              Text('100%', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          if (buckets.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${_shortDate(buckets.first.startDate)} – ${_shortDate(buckets.last.endDate)}',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: colors.onSurface.withValues(alpha: 0.72)),
            ),
          ],
          const SizedBox(height: 6),
          Semantics(
            label: buckets
                .map(
                  (bucket) =>
                      '${_chartDateRange(bucket)}: ${bucket.completed} of ${bucket.total} prayer hours, ${_percent(bucket.rate)}',
                )
                .join('. '),
            child: ExcludeSemantics(
              child: SizedBox(
                height: 154,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var index = 0; index < buckets.length; index++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Tooltip(
                            message: localizedText(
                              language,
                              '${_chartDateRange(buckets[index])}\n${buckets[index].completed} / ${buckets[index].total} የጸሎት ሰዓቶች\n${_percent(buckets[index].rate)}',
                              '${_chartDateRange(buckets[index])}\n${buckets[index].completed} / ${buckets[index].total} prayer hours\n${_percent(buckets[index].rate)} complete',
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: 112,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: SizedBox(
                                      width: 18,
                                      height: 112,
                                      child: Stack(
                                        alignment: Alignment.bottomCenter,
                                        children: [
                                          Positioned.fill(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: colors.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                            ),
                                          ),
                                          if (buckets[index].rate > 0)
                                            Container(
                                              height: 112 * buckets[index].rate,
                                              decoration: BoxDecoration(
                                                color:
                                                    index == buckets.length - 1
                                                    ? colors.secondary
                                                    : colors.primary,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 18,
                                  child: Text(
                                    _chartTick(
                                      buckets[index],
                                      summary.rangeDays,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.summary, required this.language});

  final PrayerAnalysisSummary summary;
  final String language;

  @override
  Widget build(BuildContext context) {
    final best = summary.bestDay;
    final bestText = best == null
        ? localizedText(language, 'ገና አልተመዘገበም', 'No best day yet')
        : '${_shortDate(best.date)} · ${best.completed}/7 (${_percent(best.rate)})';
    return _Panel(
      title: localizedText(language, 'ዋና ውጤቶች', 'Highlights'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Highlight(
            icon: Icons.star_outline,
            label: localizedText(language, 'ምርጥ ቀን', 'Best Day'),
            value: bestText,
          ),
          const Divider(height: 24),
          _Highlight(
            icon: Icons.trending_up,
            label: localizedText(language, 'በጣም የተለመደ ጸሎት', 'Most Consistent'),
            value: _performanceLabel(
              summary,
              highest: true,
              language: language,
            ),
          ),
          const Divider(height: 24),
          _Highlight(
            icon: Icons.info_outline,
            label: localizedText(language, 'ትኩረት የሚፈልግ', 'Needs Attention'),
            value: _performanceLabel(
              summary,
              highest: false,
              language: language,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.summary, required this.language});

  final PrayerAnalysisSummary summary;
  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _Panel(
      title: localizedText(language, 'የጸሎት ሰዓት እድገት', 'Prayer-hour progress'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (
            var index = 0;
            index < summary.prayerPerformance.length && index < hours.length;
            index++
          ) ...[
            if (index > 0) const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final performance = summary.prayerPerformance[index];
                final hourName = localizedText(
                  language,
                  _prayerHourNamesAmharic[index],
                  hours[index].en,
                );
                final percent = _percent(performance.rate);
                return Semantics(
                  label: localizedText(
                    language,
                    '$hourName፦ ${performance.completed} ከ ${performance.expected}፣ $percent',
                    '$hourName: ${performance.completed} of ${performance.expected}, $percent',
                  ),
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                hourName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontFamily: language == 'eth'
                                          ? 'AbyssinicaSIL'
                                          : null,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              localizedText(
                                language,
                                '${performance.completed} ከ ${performance.expected}',
                                '${performance.completed} of ${performance.expected}',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 42,
                              child: Text(
                                percent,
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            minHeight: 9,
                            value: performance.rate.clamp(0.0, 1.0),
                            color: colors.primary,
                            backgroundColor: colors.onSurface.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colors.secondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaniaAnalysis extends StatefulWidget {
  const _MetaniaAnalysis({required this.rangeDays, required this.language});

  final int rangeDays;
  final String language;

  @override
  State<_MetaniaAnalysis> createState() => _MetaniaAnalysisState();
}

class _MetaniaAnalysisState extends State<_MetaniaAnalysis> {
  late Future<List<int>> _totalsFuture;

  @override
  void initState() {
    super.initState();
    _totalsFuture = _loadTotals(widget.rangeDays);
  }

  @override
  void didUpdateWidget(covariant _MetaniaAnalysis oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rangeDays != widget.rangeDays) {
      _totalsFuture = _loadTotals(widget.rangeDays);
    }
  }

  Future<List<int>> _loadTotals(int rangeDays) async {
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final firstDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: rangeDays - 1));
    final totals = List<int>.filled(hours.length, 0);
    for (var dayIndex = 0; dayIndex < rangeDays; dayIndex++) {
      final date = firstDay.add(Duration(days: dayIndex));
      final dateKey = '${date.year}-${date.month}-${date.day}';
      for (var hourIndex = 0; hourIndex < hours.length; hourIndex++) {
        totals[hourIndex] +=
            preferences.getInt('metania_${dateKey}_$hourIndex') ?? 0;
      }
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final rangeDays = widget.rangeDays;
    final language = widget.language;
    final colors = Theme.of(context).colorScheme;
    return _Panel(
      title: localizedText(language, 'የስግደት ትንተና', 'Metania progress'),
      child: FutureBuilder<List<int>>(
        future: _totalsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final totals = snapshot.data ?? List<int>.filled(hours.length, 0);
          final total = totals.fold<int>(0, (sum, count) => sum + count);
          final targetPerHour = AppConstants.defaultMetaniaCount * rangeDays;
          final totalTarget = targetPerHour * hours.length;
          final totalProgress = totalTarget == 0
              ? 0.0
              : (total / totalTarget).clamp(0.0, 1.0).toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.self_improvement, color: colors.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizedText(language, 'ጠቅላላ ስግደት', 'Total Metania'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          localizedText(
                            language,
                            'በ $rangeDays ቀን',
                            'Across $rangeDays days',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$total',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Semantics(
                label: localizedText(
                  language,
                  'የግብ እድገት ${(totalProgress * 100).round()} በመቶ፣ $total ከ $totalTarget',
                  'Metania goal progress ${_percent(totalProgress)}, $total of $totalTarget',
                ),
                child: ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: totalProgress,
                      minHeight: 9,
                      color: colors.primary,
                      backgroundColor: colors.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                localizedText(
                  language,
                  'የግብ እድገት: ${(totalProgress * 100).round()}%  ·  $total / $totalTarget',
                  'Goal progress: ${(totalProgress * 100).round()}%  ·  $total / $totalTarget',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                localizedText(
                  language,
                  'የዕያንዳንዱ ሰዓት ግብ በቀን ${AppConstants.defaultMetaniaCount} ነው።',
                  'The existing target is ${AppConstants.defaultMetaniaCount} per prayer hour per day.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Text(
                localizedText(language, 'በጸሎት ሰዓት', 'By Prayer Hour'),
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 720 ? 2 : 1;
                  const gap = 20.0;
                  final width = columns == 1
                      ? constraints.maxWidth
                      : (constraints.maxWidth - gap) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: 16,
                    children: [
                      for (var index = 0; index < hours.length; index++)
                        SizedBox(
                          width: width,
                          child: _MetaniaHourRow(
                            index: index,
                            count: totals[index],
                            target: targetPerHour,
                            language: language,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetaniaHourRow extends StatelessWidget {
  const _MetaniaHourRow({
    required this.index,
    required this.count,
    required this.target,
    required this.language,
  });

  final int index;
  final int count;
  final int target;
  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hourName = localizedText(
      language,
      _prayerHourNamesAmharic[index],
      hours[index].en,
    );
    final progress = target == 0
        ? 0.0
        : (count / target).clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: localizedText(
        language,
        '$hourName፦ $count ከ $target',
        '$hourName: $count of $target',
      ),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    hourName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: language == 'eth' ? 'AbyssinicaSIL' : null,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$count / $target',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: colors.primary,
                backgroundColor: colors.onSurface.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _percent(double rate) => '${(rate * 100).round()}%';

String _shortDate(DateTime date) => '${date.month}/${date.day}';

class _ChartBucket {
  const _ChartBucket({
    required this.startDate,
    required this.endDate,
    required this.completed,
    required this.total,
  });

  final DateTime startDate;
  final DateTime endDate;
  final int completed;
  final int total;

  double get rate => total == 0 ? 0 : completed / total;
}

List<_ChartBucket> _chartBuckets(List<DailyPrayerStatistic> days) {
  if (days.length <= 14) {
    return [
      for (final day in days)
        _ChartBucket(
          startDate: day.date,
          endDate: day.date,
          completed: day.completed,
          total: day.total,
        ),
    ];
  }

  final bucketSize = (days.length / 7).ceil();
  return _fixedChartBuckets(days, bucketSize);
}

List<_ChartBucket> _fixedChartBuckets(
  List<DailyPrayerStatistic> days,
  int periodLength,
) => [
  for (var start = 0; start < days.length; start += periodLength)
    _makeChartBucket(
      days.sublist(start, (start + periodLength).clamp(0, days.length)),
    ),
];

_ChartBucket _makeChartBucket(List<DailyPrayerStatistic> days) => _ChartBucket(
  startDate: days.first.date,
  endDate: days.last.date,
  completed: days.fold(0, (sum, day) => sum + day.completed),
  total: days.fold(0, (sum, day) => sum + day.total),
);

String _chartDateRange(_ChartBucket bucket) =>
    bucket.startDate == bucket.endDate
    ? _shortDate(bucket.startDate)
    : '${_shortDate(bucket.startDate)}–${_shortDate(bucket.endDate)}';

String _chartTick(_ChartBucket bucket, int rangeDays) {
  if (rangeDays <= 14) return '${bucket.startDate.day}';
  return '${bucket.startDate.month}/${bucket.startDate.day}';
}

String _performanceLabel(
  PrayerAnalysisSummary summary, {
  required bool highest,
  required String language,
}) {
  final performance = [...summary.prayerPerformance]
    ..sort(
      (a, b) => highest ? b.rate.compareTo(a.rate) : a.rate.compareTo(b.rate),
    );
  if (performance.isEmpty) {
    return localizedText(language, 'ገና አልተመዘገበም', 'No record yet');
  }
  final index = hours.indexWhere(
    (hour) => hour.en == performance.first.prayerId,
  );
  final name = index < 0
      ? performance.first.prayerId
      : localizedText(language, hours[index].ge, hours[index].en);
  return '$name · ${_percent(performance.first.rate)}';
}
