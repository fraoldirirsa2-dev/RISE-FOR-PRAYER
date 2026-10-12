import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/data/prayer_data.dart';
import 'package:rise_for_prayer/features/analysis/models/analysis_models.dart';
import 'package:rise_for_prayer/features/analysis/providers/analysis_provider.dart';
import 'package:rise_for_prayer/providers/prayer_provider.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:rise_for_prayer/utils/localization.dart';
import 'package:rise_for_prayer/utils/constants.dart';
import 'package:rise_for_prayer/utils/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AnalysisScreen – Top-level
// ─────────────────────────────────────────────────────────────────────────────
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
        title: Text(
          localizedText(language, 'የጸሎት ትንተና', 'Prayer Analysis'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
                    const SizedBox(height: 20),
                    if (!summary.hasHistory ||
                        summary.dailyStatistics.isEmpty) ...[
                      _EmptyAnalysisState(language: language),
                      const SizedBox(height: 20),
                    ] else ...[
                      // ── Hero ring card ──
                      _HeroProgressCard(
                        completedHours: prayer.completedHours,
                        summary: summary,
                        language: language,
                      ),
                      const SizedBox(height: 16),
                      // ── Quick stats row ──
                      _QuickStatsRow(
                        summary: summary,
                        language: language,
                      ),
                      const SizedBox(height: 20),
                      // ── Trend chart ──
                      _TrendChart(summary: summary, language: language),
                      const SizedBox(height: 16),
                      // ── Prayer-hour breakdown + Highlights ──
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _HourBreakdownCard(
                                summary: summary,
                                language: language,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _HighlightsCard(
                                summary: summary,
                                language: language,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _HourBreakdownCard(
                          summary: summary,
                          language: language,
                        ),
                        const SizedBox(height: 16),
                        _HighlightsCard(
                          summary: summary,
                          language: language,
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Range selector – pill-style segmented control
// ─────────────────────────────────────────────────────────────────────────────
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
    final colors = Theme.of(context).colorScheme;
    final entries = [
      (7, localizedText(language, '7 ቀን', '7D')),
      (30, localizedText(language, '30 ቀን', '30D')),
      (90, localizedText(language, '3 ወር', '3M')),
      (365, localizedText(language, '1 ዓመት', '1Y')),
    ];
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final entry in entries)
            Expanded(
              child: GestureDetector(
                onTap: () => analysis.setRange(entry.$1, prayer),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: analysis.rangeDays == entry.$1
                        ? colors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    entry.$2,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: analysis.rangeDays == entry.$1
                          ? colors.onPrimary
                          : colors.onSurface.withValues(alpha: 0.7),
                      fontWeight: analysis.rangeDays == entry.$1
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyAnalysisState extends StatelessWidget {
  const _EmptyAnalysisState({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.self_improvement,
              size: 38,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            localizedText(
              language,
              'የጸሎት ታሪክ እየተጠራ ነው',
              'No prayer history yet',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
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

// ─────────────────────────────────────────────────────────────────────────────
// Hero progress card – circular ring + today's hours
// ─────────────────────────────────────────────────────────────────────────────
const _prayerHourNamesAmharic = [
  'ነግህ',
  'ሠለስት',
  'ቀትር',
  'ተሰዓት',
  'ሠርክ',
  'ንዋም',
  'መንፈቀ ሌሊት',
];

class _HeroProgressCard extends StatelessWidget {
  const _HeroProgressCard({
    required this.completedHours,
    required this.summary,
    required this.language,
  });

  final List<bool> completedHours;
  final PrayerAnalysisSummary summary;
  final String language;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completed = completedHours.where((v) => v).length;
    final rate = completed / 7;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A0F20),
                  const Color(0xFF2A1520),
                  const Color(0xFF1A0F20),
                ]
              : [
                  const Color(0xFF5B1424),
                  const Color(0xFF7A1D33),
                  const Color(0xFF5B1424),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.burgundy.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ── Title ──
            Text(
              localizedText(language, 'የዛሬ የጸሎት ጉዞ', "Today's Prayer Journey"),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            // ── Ring + Score ──
            Row(
              children: [
                // Circular progress
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CustomPaint(
                    painter: _CircularProgressPainter(
                      progress: rate,
                      trackColor: Colors.white.withValues(alpha: 0.12),
                      progressColor: AppColors.gold,
                      strokeWidth: 8,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$completed',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            localizedText(language, 'ከ 7', 'of 7'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Prayer hour status chips
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < 7; i++)
                        _PrayerChip(
                          name: localizedText(
                            language,
                            _prayerHourNamesAmharic[i],
                            hours[i].en,
                          ),
                          completed: i < completedHours.length &&
                              completedHours[i],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // ── Completion bar ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      localizedText(language, 'እድገት', 'Progress'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                    Text(
                      _percent(rate),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                        minHeight: 8,
                        color: AppColors.gold,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerChip extends StatelessWidget {
  const _PrayerChip({required this.name, required this.completed});

  final String name;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: completed
            ? AppColors.gold.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: completed
              ? AppColors.gold.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: completed
                ? AppColors.gold
                : Colors.white.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: completed
                  ? AppColors.gold
                  : Colors.white.withValues(alpha: 0.6),
              fontWeight: completed ? FontWeight.w600 : FontWeight.w400,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick stats – horizontal scrolling stat cards
// ─────────────────────────────────────────────────────────────────────────────
class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.summary, required this.language});

  final PrayerAnalysisSummary summary;
  final String language;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (
        Icons.pie_chart_outline,
        localizedText(language, 'የጸሎት መጠን', 'Completion'),
        _percent(summary.completionRate),
        '${summary.totalCompleted}/${summary.totalExpected}',
      ),
      (
        Icons.local_fire_department_outlined,
        localizedText(language, 'የአሁኑ ተከታታይ', 'Current Streak'),
        '${summary.currentStreak}',
        localizedText(language, 'ቀናት', 'days'),
      ),
      (
        Icons.emoji_events_outlined,
        localizedText(language, 'ምርጥ ተከታታይ', 'Best Streak'),
        '${summary.bestStreak}',
        localizedText(language, 'ቀናት', 'days'),
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _StatMiniCard(
              icon: stats[i].$1,
              label: stats[i].$2,
              value: stats[i].$3,
              detail: stats[i].$4,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  const _StatMiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.secondary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trend chart – gradient bars with rounded tops
// ─────────────────────────────────────────────────────────────────────────────
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.summary, required this.language});

  final PrayerAnalysisSummary summary;
  final String language;

  @override
  Widget build(BuildContext context) {
    final buckets = _chartBuckets(summary.dailyStatistics);
    final colors = Theme.of(context).colorScheme;
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  localizedText(
                    language,
                    'እድገት በጊዜ',
                    'Prayer Completion Trend',
                  ),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            localizedText(
              language,
              'አሞሌዎቹ በጊዜ ክፍሎች የተጠናቀቁ ጸሎቶችን መጠን ያነጻጽራሉ',
              'Comparing completion rates across the selected period',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (buckets.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '${_shortDate(buckets.first.startDate)} – ${_shortDate(buckets.last.endDate)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Semantics(
            label: buckets
                .map(
                  (b) =>
                      '${_chartDateRange(b)}: ${b.completed} of ${b.total} prayer hours, ${_percent(b.rate)}',
                )
                .join('. '),
            child: ExcludeSemantics(
              child: SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < buckets.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _GradientBar(
                            bucket: buckets[i],
                            isLast: i == buckets.length - 1,
                            maxHeight: 130,
                            rangeDays: summary.rangeDays,
                            language: language,
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

class _GradientBar extends StatelessWidget {
  const _GradientBar({
    required this.bucket,
    required this.isLast,
    required this.maxHeight,
    required this.rangeDays,
    required this.language,
  });

  final _ChartBucket bucket;
  final bool isLast;
  final double maxHeight;
  final int rangeDays;
  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final barHeight = maxHeight * bucket.rate;
    return Tooltip(
      message: localizedText(
        language,
        '${_chartDateRange(bucket)}\n${bucket.completed} / ${bucket.total} የጸሎት ሰዓቶች\n${_percent(bucket.rate)}',
        '${_chartDateRange(bucket)}\n${bucket.completed} / ${bucket.total} prayer hours\n${_percent(bucket.rate)} complete',
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (bucket.rate > 0)
            Container(
              width: 22,
              height: barHeight.clamp(4.0, maxHeight),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: isLast
                      ? [AppColors.gold, AppColors.goldLight]
                      : [colors.primary, colors.primary.withValues(alpha: 0.6)],
                ),
                boxShadow: isLast
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            )
          else
            Container(
              width: 22,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 18,
            child: Text(
              _chartTick(bucket, rangeDays),
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: isLast
                    ? colors.secondary
                    : colors.onSurface.withValues(alpha: 0.5),
                fontWeight: isLast ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prayer-hour breakdown – modern pill progress bars
// ─────────────────────────────────────────────────────────────────────────────
class _HourBreakdownCard extends StatelessWidget {
  const _HourBreakdownCard({required this.summary, required this.language});

  final PrayerAnalysisSummary summary;
  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_filled, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  localizedText(
                    language,
                    'የጸሎት ሰዓት እድገት',
                    'Prayer-hour Progress',
                  ),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (
            var i = 0;
            i < summary.prayerPerformance.length && i < hours.length;
            i++
          ) ...[
            if (i > 0) const SizedBox(height: 14),
            _HourProgressRow(
              index: i,
              performance: summary.prayerPerformance[i],
              language: language,
            ),
          ],
        ],
      ),
    );
  }
}

class _HourProgressRow extends StatelessWidget {
  const _HourProgressRow({
    required this.index,
    required this.performance,
    required this.language,
  });

  final int index;
  final PrayerPerformance performance;
  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hourName = localizedText(
      language,
      _prayerHourNamesAmharic[index],
      hours[index].en,
    );
    final percent = _percent(performance.rate);
    final barColor = _hourBarColor(performance.rate);
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
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: barColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    percent,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: barColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: performance.rate.clamp(0.0, 1.0),
                color: barColor,
                backgroundColor: colors.onSurface.withValues(alpha: 0.07),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _hourBarColor(double rate) {
    if (rate >= 0.8) return const Color(0xFF2E7D32); // green
    if (rate >= 0.5) return AppColors.gold;
    if (rate >= 0.25) return AppColors.terracotta;
    return const Color(0xFFB71C1C); // deep red
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Highlights card – milestone badge + best day + consistency
// ─────────────────────────────────────────────────────────────────────────────
class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard({required this.summary, required this.language});

  final PrayerAnalysisSummary summary;
  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final best = summary.bestDay;
    final bestText = best == null
        ? localizedText(language, 'ገና አልተመዘገበም', 'No best day yet')
        : '${_shortDate(best.date)} · ${best.completed}/7 (${_percent(best.rate)})';

    // Spiritual milestone
    final hasActiveStreak = summary.currentStreak >= 3;
    final hasHighCompletion = summary.completionRate >= 0.7;

    final milestoneIcon = hasActiveStreak
        ? Icons.workspace_premium
        : (hasHighCompletion ? Icons.shield_outlined : Icons.auto_awesome);
    final milestoneColor = hasActiveStreak
        ? AppColors.gold
        : (hasHighCompletion ? const Color(0xFF2E7D32) : colors.secondary);
    final milestoneTitle = hasActiveStreak
        ? localizedText(
            language, 'ጽናት ያለው የጸሎት ጉዞ', 'Steadfast Prayer Journey')
        : (hasHighCompletion
            ? localizedText(language, 'ታማኝ አገልጋይ', 'Faithful Watchman')
            : localizedText(
                language, 'የበረከት ጅማሮ', 'Beginning of Blessing'));
    final milestoneDesc = hasActiveStreak
        ? localizedText(
            language,
            'ለ ${summary.currentStreak} ተከታታይ ቀናት የጸሎት ሰዓታትን ጠብቀዋል። በጸሎት ጽኑ!',
            'You have maintained your canonical prayer hours for ${summary.currentStreak} consecutive days. Stay vigilant!',
          )
        : (hasHighCompletion
            ? localizedText(
                language,
                'በዚህ ጊዜ ውስጥ አብዛኛዎቹን የጸሎት ሰዓታት አጠናቀዋል። መልካም መንፈሳዊ ትጋት!',
                'You have completed the vast majority of your prayer hours in this period.',
              )
            : localizedText(
                language,
                '"ሳታቋርጡ ጸልዩ" (1ኛ ተሰ 5፥17)። እያንዳንዱ ሰዓት አዲስ ጸጋ አለው።',
                '"Pray without ceasing" (1 Thess 5:17). Each hour is a new blessing.',
              ));

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  localizedText(language, 'ዋና ውጤቶች', 'Highlights'),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // ── Milestone badge ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  milestoneColor.withValues(alpha: 0.08),
                  milestoneColor.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: milestoneColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: milestoneColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(milestoneIcon, color: milestoneColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        milestoneTitle,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: milestoneColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        milestoneDesc,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // ── Highlight rows ──
          _HighlightRow(
            icon: Icons.star_rounded,
            iconColor: AppColors.gold,
            label: localizedText(language, 'ምርጥ ቀን', 'Best Day'),
            value: bestText,
          ),
          const SizedBox(height: 14),
          _HighlightRow(
            icon: Icons.trending_up,
            iconColor: const Color(0xFF2E7D32),
            label: localizedText(
                language, 'በጣም የተለመደ ጸሎት', 'Most Consistent'),
            value: _performanceLabel(
              summary,
              highest: true,
              language: language,
            ),
          ),
          const SizedBox(height: 14),
          _HighlightRow(
            icon: Icons.priority_high_rounded,
            iconColor: AppColors.terracotta,
            label: localizedText(
                language, 'ትኩረት የሚፈልግ', 'Needs Attention'),
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

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metania analysis
// ─────────────────────────────────────────────────────────────────────────────
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
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.self_improvement,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  localizedText(language, 'የስግደት ትንተና', 'Metania Progress'),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<int>>(
            future: _totalsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final totals =
                  snapshot.data ?? List<int>.filled(hours.length, 0);
              final total = totals.fold<int>(0, (sum, c) => sum + c);
              final targetPerHour =
                  AppConstants.defaultMetaniaCount * rangeDays;
              final totalTarget = targetPerHour * hours.length;
              final totalProgress = totalTarget == 0
                  ? 0.0
                  : (total / totalTarget).clamp(0.0, 1.0).toDouble();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Total summary row ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: CustomPaint(
                            painter: _CircularProgressPainter(
                              progress: totalProgress,
                              trackColor:
                                  colors.onSurface.withValues(alpha: 0.08),
                              progressColor: colors.primary,
                              strokeWidth: 5,
                            ),
                            child: Center(
                              child: Text(
                                '${(totalProgress * 100).round()}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colors.primary,
                                      fontSize: 10,
                                    ),
                              ),
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
                                  'ጠቅላላ ስግደት',
                                  'Total Metania',
                                ),
                                style:
                                    Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                localizedText(
                                  language,
                                  'በ $rangeDays ቀን · $total / $totalTarget',
                                  'Across $rangeDays days · $total / $totalTarget',
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$total',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
                        runSpacing: 14,
                        children: [
                          for (var i = 0; i < hours.length; i++)
                            SizedBox(
                              width: width,
                              child: _MetaniaHourRow(
                                index: i,
                                count: totals[i],
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
        ],
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
    final progress =
        target == 0 ? 0.0 : (count / target).clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: localizedText(
        language,
        '$hourName፦ $count ከ $target',
        '$hourName: $count of $target',
      ),
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hourName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontFamily:
                                    language == 'eth' ? 'AbyssinicaSIL' : null,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      Text(
                        '$count / $target',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color: colors.primary,
                      backgroundColor:
                          colors.onSurface.withValues(alpha: 0.07),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Glass-style panel with subtle elevation and border
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Circular arc progress painter
class _CircularProgressPainter extends CustomPainter {
  const _CircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.trackColor != trackColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
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
