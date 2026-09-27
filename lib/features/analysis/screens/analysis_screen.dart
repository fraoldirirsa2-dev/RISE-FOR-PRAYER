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
    final prayer = ref.read(prayerProvider);
    final language = ref.watch(settingsProvider).language;
    final summary = analysis.summary;
    final today = summary.dailyStatistics.isEmpty
        ? null
        : summary.dailyStatistics.last;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizedText(language, 'የጸሎት ትንተና', 'Prayer Analysis')),
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
                          const SizedBox(height: 10),
                          _AnalysisGuide(language: language),
                          const SizedBox(height: 16),
                          if (!summary.hasHistory) ...[
                            _NoPrayerHistory(language: language),
                            const SizedBox(height: 16),
                          ],
                          _SummaryGrid(
                            summary: summary,
                            today: today!,
                            language: language,
                          ),
                          const SizedBox(height: 16),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _WeeklyChart(
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
                            _WeeklyChart(summary: summary, language: language),
                            const SizedBox(height: 16),
                            _StreakCard(summary: summary, language: language),
                          ],
                          const SizedBox(height: 16),
                          _PerformanceCard(
                            summary: summary,
                            language: language,
                          ),
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

class _AnalysisGuide extends StatelessWidget {
  const _AnalysisGuide({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              localizedText(
                language,
                'ጊዜውን ይምረጡ። እያንዳንዱ የተጠናቀቀ ሰዓት ከ7 የዕለት ጸሎቶች አንዱ ነው። የአሞሌዎቹ ርዝመት የተጠናቀቀውን መጠን ያሳያል።',
                'Choose a time range above. Each day has 7 prayer hours; longer bars mean more hours completed.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.summary,
    required this.today,
    required this.language,
  });

  final PrayerAnalysisSummary summary;
  final DailyPrayerStatistic today;
  final String language;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: columns == 4 ? 135 : 150,
          children: [
            _MetricCard(
              label: localizedText(language, 'የዛሬ እድገት', "Today's Progress"),
              value: '${today.completed} / 7',
              detail: _percent(today.rate),
            ),
            _MetricCard(
              label: localizedText(language, 'የጸሎት መጠን', 'Completion Rate'),
              value: _percent(summary.completionRate),
              detail: '${summary.totalCompleted} / ${summary.totalExpected}',
            ),
            _MetricCard(
              label: localizedText(language, 'የአሁኑ ተከታታይ ጊዜ', 'Current Streak'),
              value: '${summary.currentStreak}',
              detail: localizedText(language, 'ቀናት', 'days'),
            ),
            _MetricCard(
              label: localizedText(language, 'ምርጥ ተከታታይ ጊዜ', 'Best Streak'),
              value: '${summary.bestStreak}',
              detail: localizedText(language, 'ቀናት', 'days'),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(detail, style: TextStyle(color: colors.primary)),
          ],
        ),
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
    final days = summary.dailyStatistics.length <= 14
        ? summary.dailyStatistics
        : _bucketDays(summary.dailyStatistics, 7);
    final primary = Theme.of(context).colorScheme.primary;
    return _Panel(
      title: localizedText(language, 'እድገት በቀን', 'Progress by Day'),
      child: Semantics(
        label: days
            .map(
              (day) => '${_shortDate(day.date)}: ${day.completed}/${day.total}',
            )
            .join(', '),
        child: SizedBox(
          height: 190,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Tooltip(
                      message:
                          '${_shortDate(day.date)}\n${day.completed} / ${day.total} prayers\n${_percent(day.rate)}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${day.completed}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 120,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: day.total == 0 ? 0 : 120 * day.rate,
                                constraints: const BoxConstraints(minHeight: 3),
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _shortDate(day.date),
                            style: Theme.of(context).textTheme.bodySmall,
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
            label: localizedText(language, 'ምርጥ ቀን', 'Best Day'),
            value: bestText,
          ),
          const Divider(height: 24),
          _Highlight(
            label: localizedText(language, 'በጣም የተለመደ ጸሎት', 'Most Consistent'),
            value: _performanceLabel(
              summary,
              highest: true,
              language: language,
            ),
          ),
          const Divider(height: 24),
          _Highlight(
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
      title: localizedText(language, 'የጸሎት አፈጻጸም', 'Prayer Performance'),
      child: Column(
        children: [
          for (var index = 0; index < summary.prayerPerformance.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 94,
                    child: Text(
                      localizedText(language, hours[index].ge, hours[index].en),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 9,
                        value: summary.prayerPerformance[index].rate,
                        backgroundColor: colors.onSurface.withValues(
                          alpha: 0.1,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      _percent(summary.prayerPerformance[index].rate),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
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
  const _Highlight({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _NoPrayerHistory extends StatelessWidget {
  const _NoPrayerHistory({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(localizedText(
        language,
        'የጸሎት ታሪክዎ እዚህ ይታያል። ለመጀመር የጸሎት ሰዓትን ያጠናቅቁ።',
        'Prayer history will appear here as you mark prayer hours complete.',
      )),
    ),
  );
}

class _MetaniaAnalysis extends StatelessWidget {
  const _MetaniaAnalysis({required this.rangeDays, required this.language});

  final int rangeDays;
  final String language;

  Future<List<int>> _loadTotals() async {
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: rangeDays - 1));
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
    final colors = Theme.of(context).colorScheme;
    return _Panel(
      title: localizedText(language, 'የስግደት ትንተና', 'Metania progress'),
      child: FutureBuilder<List<int>>(
        future: _loadTotals(),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedText(language, 'ጠቅላላ ስግደት', 'Total Metania'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$total',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            localizedText(language, 'በ $rangeDays ቀን', 'in $rangeDays days'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: totalProgress,
                        minHeight: 7,
                        backgroundColor: colors.onPrimaryContainer.withValues(alpha: 0.12),
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
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                localizedText(
                  language,
                  'ቁጥሩ ከመጀመሪያው ጸሎት ጀምሮ ለእያንዳንዱ ሰዓት ተለይቶ ይታያል።',
                  'Each hour has a goal of ${AppConstants.defaultMetaniaCount} per day. Hours are listed from Prime onward.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              for (var index = 0; index < hours.length; index++) ...[
                if (index > 0) const SizedBox(height: 14),
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${index + 1}. ${localizedText(language, hours[index].ge, hours[index].en)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${totals[index]} / $targetPerHour',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: targetPerHour == 0
                            ? 0
                            : (totals[index] / targetPerHour)
                                .clamp(0.0, 1.0)
                                .toDouble(),
                        minHeight: 7,
                        backgroundColor: colors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

String _percent(double rate) => '${(rate * 100).round()}%';

String _shortDate(DateTime date) => '${date.month}/${date.day}';

List<DailyPrayerStatistic> _bucketDays(
  List<DailyPrayerStatistic> days,
  int buckets,
) {
  final result = <DailyPrayerStatistic>[];
  final size = (days.length / buckets).ceil();
  for (var start = 0; start < days.length; start += size) {
    final group = days.skip(start).take(size).toList();
    result.add(
      DailyPrayerStatistic(
        date: group.first.date,
        completed: group.fold(0, (sum, day) => sum + day.completed),
        total: group.fold(0, (sum, day) => sum + day.total),
      ),
    );
  }
  return result;
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
