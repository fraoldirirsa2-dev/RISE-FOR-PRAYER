import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/data/prayer_data.dart';
import 'package:rise_for_prayer/features/prayer_hours/domain/prayer_schedule.dart';
import 'package:rise_for_prayer/providers/calendar_provider.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:rise_for_prayer/providers/prayer_provider.dart';
import 'package:rise_for_prayer/services/time_service.dart';
import 'package:rise_for_prayer/services/ethiopian_observance_service.dart';
import 'package:rise_for_prayer/utils/colors.dart';
import 'package:rise_for_prayer/utils/localization.dart';
import 'package:rise_for_prayer/widgets/eth_cross.dart';
import 'package:rise_for_prayer/widgets/gold_divider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static const _observances = EthiopianObservanceService();
  bool _showEth = false;
  DateTime _visibleMonth = _monthStart(TimeService.currentNow());
  String? _scheduledTodaySync;

  static DateTime _monthStart(DateTime date) => DateTime(date.year, date.month);

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context) {
    final calendar = ref.watch(calendarProvider);
    final settings = ref.watch(settingsProvider);
    final prayer = ref.watch(prayerProvider);
    final timeService = ref.watch(timeServiceProvider);
    final todayKey = _dateKey(timeService.now);
    if (_scheduledTodaySync != todayKey) {
      _scheduledTodaySync = todayKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) calendar.syncToday(timeService.now);
      });
    }
    final monthStart = DateTime(_visibleMonth.year, _visibleMonth.month);
    final gregorianDaysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final today = timeService.now;
    final selectedDate = calendar.selectedDate;
    // In Ethiopian mode `_visibleMonth` is the actual Gregorian date of the
    // Ethiopian month's first day. Do not truncate it to the Gregorian month
    // start: that can fall in the previous Ethiopian month.
    final visibleEthiopianDate = timeService.toEthiopian(_visibleMonth);
    final displayedEthiopianMonth = visibleEthiopianDate.month;
    final displayedEthiopianYear = visibleEthiopianDate.year;
    final displayedMonthStart = _ethiopianMonthStart(
      displayedEthiopianYear,
      displayedEthiopianMonth,
      timeService,
    );
    final daysInMonth = _showEth
        ? _ethiopianDaysInMonth(
            displayedEthiopianYear,
            displayedEthiopianMonth,
            timeService,
          )
        : gregorianDaysInMonth;
    final leadingDays =
        (_showEth ? displayedMonthStart : monthStart).weekday % 7;
    final DateTime Function(int) dateForDay = _showEth
        ? (day) => timeService.toGregorian(
            EthiopianDate(
              year: displayedEthiopianYear,
              month: displayedEthiopianMonth,
              day: day,
            ),
          )
        : (day) => DateTime(_visibleMonth.year, _visibleMonth.month, day);
    final background = Theme.of(context).scaffoldBackgroundColor;
    final colors = Theme.of(context).colorScheme;
    final isLightAppearance = colors.brightness == Brightness.light;

    return Scaffold(
      backgroundColor: background,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                localizedText(settings.language, 'የቀን መቁጠሪያ', 'Calendar'),
                style: GoogleFonts.cinzel(fontSize: 16, color: colors.primary),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      _toggleButton(
                        localizedText(settings.language, 'ኢ.ኦ', 'Ethiopic'),
                        true,
                      ),
                      _toggleButton(
                        localizedText(settings.language, 'ግሪጎሪያን', 'Gregorian'),
                        false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _todaySummary(today, selectedDate, timeService, settings.language),
            const SizedBox(height: 16),
            _upcomingWeek(today, timeService, settings.language, calendar),
            const SizedBox(height: 16),
            // Month header
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showEth
                          ? (settings.language == 'eth'
                                ? ethMonths[displayedEthiopianMonth - 1]
                                : ethMonthsEnglish[displayedEthiopianMonth - 1])
                          : DateFormat('MMMM').format(_visibleMonth),
                      style: GoogleFonts.cinzel(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      _showEth
                          ? '$displayedEthiopianYear ${localizedText(settings.language, 'ዓ.ም', 'E.C.').trim()}'
                          : '${_visibleMonth.year}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: localizedText(
                            settings.language,
                            'ዓመት ወደ ኋላ',
                            'Previous year',
                          ),
                          icon: const Icon(Icons.keyboard_double_arrow_left),
                          onPressed: () => setState(
                            () => _shiftVisibleYear(-1, timeService),
                          ),
                        ),
                        IconButton(
                          tooltip: localizedText(
                            settings.language,
                            'ወደ ቀን ሂድ',
                            'Go to date',
                          ),
                          icon: const Icon(Icons.event_outlined),
                          onPressed: () =>
                              _pickDate(calendar, settings.language),
                        ),
                        IconButton(
                          tooltip: localizedText(
                            settings.language,
                            'ዓመት ወደ ፊት',
                            'Next year',
                          ),
                          icon: const Icon(Icons.keyboard_double_arrow_right),
                          onPressed: () =>
                              setState(() => _shiftVisibleYear(1, timeService)),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _monthButton(Icons.chevron_left, -1, timeService),
                    IconButton(
                      tooltip: localizedText(settings.language, 'ዛሬ', 'Today'),
                      icon: const Icon(Icons.today_outlined, size: 19),
                      color: colors.primary,
                      onPressed: () {
                        calendar.selectToday();
                        setState(() {
                          final today = TimeService.currentNow();
                          _visibleMonth = _monthForDisplay(
                            today,
                            timeService,
                            _showEth,
                          );
                        });
                      },
                    ),
                    widget.embedded
                        ? Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                _toggleButton(
                                  localizedText(
                                    settings.language,
                                    'ኢ.ኦ',
                                    'Ethiopic',
                                  ),
                                  true,
                                ),
                                _toggleButton(
                                  localizedText(
                                    settings.language,
                                    'ግሪጎሪያን',
                                    'Gregorian',
                                  ),
                                  false,
                                ),
                              ],
                            ),
                          )
                        : const EthCross(size: 24, opacity: 0.6),
                    _monthButton(Icons.chevron_right, 1, timeService),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Calendar grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  isLightAppearance ? 24 : 12,
                ),
                color: colors.surface,
                border: Border.all(
                  color:
                      (isLightAppearance
                              ? AppColors.terracotta
                              : colors.primary)
                          .withValues(alpha: isLightAppearance ? 0.14 : 0.15),
                ),
                boxShadow: isLightAppearance
                    ? [
                        BoxShadow(
                          color: AppColors.terracotta.withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Row(
                    children:
                        (_showEth && settings.language == 'eth'
                                ? weekEth
                                : weekGreg)
                            .map(
                              (d) => Expanded(
                                child: Text(
                                  d,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      for (var row = 0; row < 6; row++)
                        _buildWeek(
                          List<int?>.generate(7, (column) {
                            final day = row * 7 + column - leadingDays + 1;
                            return day >= 1 && day <= daysInMonth ? day : null;
                          }),
                          selectedDate: selectedDate,
                          today: today,
                          dateForDay: dateForDay,
                          timeService: timeService,
                          language: settings.language,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Legend
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _legendItem(
                  localizedText(settings.language, 'ዛሬ', 'Today'),
                  AppColors.gold,
                ),
                _legendItem(
                  localizedText(settings.language, 'ተመርጧል', 'Selected'),
                  AppColors.burgundy,
                ),
                _legendItem(
                  localizedText(settings.language, 'በዓል', 'Feast'),
                  AppColors.goldDim,
                ),
                _legendItem(
                  localizedText(settings.language, 'ጾም', 'Fast'),
                  AppColors.terracotta,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _selectedDayCard(
              selectedDate,
              today,
              timeService,
              settings.language,
              _showEth,
            ),
            const SizedBox(height: 16),
            _specialDayStatus(
              selectedDate,
              timeService,
              settings.language,
              _showEth,
            ),
            const SizedBox(height: 16),
            _prayerHoursForDate(
              selectedDate,
              today,
              settings.language,
              prayer,
              timeService,
            ),
            const SizedBox(height: 16),
            const GoldDividerSmall(),
            const SizedBox(height: 16),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _toggleButton(String label, bool isEth) {
    final active = _showEth == isEth;
    final colors = Theme.of(context).colorScheme;
    final isLightAppearance = colors.brightness == Brightness.light;
    return GestureDetector(
      onTap: () {
        final selected = ref.read(calendarProvider).selectedDate;
        final timeService = ref.read(timeServiceProvider);
        setState(() {
          _showEth = isEth;
          _visibleMonth = _monthForDisplay(selected, timeService, isEth);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? (isLightAppearance
                    ? AppColors.terracotta
                    : AppColors.burgundy.withValues(alpha: 0.6))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(isLightAppearance ? 10 : 6),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: active
                ? (isLightAppearance ? Colors.white : AppColors.gold)
                : colors.onSurface.withValues(alpha: 0.58),
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _todaySummary(
    DateTime today,
    DateTime selectedDate,
    TimeService timeService,
    String language,
  ) {
    final colors = Theme.of(context).colorScheme;
    final todayEth = timeService.toEthiopian(today);
    final selectedIsToday = CalendarProvider.isSameDate(today, selectedDate);
    final weekday = DateFormat('EEEE').format(today);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            Color.lerp(colors.primary, colors.surface, 0.14)!,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.onPrimary.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.onPrimary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    localizedText(language, 'ዛሬ', 'TODAY'),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: colors.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${language == 'eth' ? ethMonths[todayEth.month - 1] : ethMonthsEnglish[todayEth.month - 1]} ${todayEth.day}, ${todayEth.year}',
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${timeService.formatGregorianDate(today)}  ·  $weekday',
                  style: GoogleFonts.ebGaramond(
                    fontSize: 16,
                    color: colors.onPrimary.withValues(alpha: 0.78),
                  ),
                ),
                if (!selectedIsToday) ...[
                  const SizedBox(height: 9),
                  Text(
                    '${localizedText(language, 'የተመረጠው ቀን', 'Calendar selection')}: ${timeService.formatGregorianDate(selectedDate)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: colors.onPrimary.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            todayEth.day.toString().padLeft(2, '0'),
            style: GoogleFonts.cinzel(
              fontSize: 56,
              fontWeight: FontWeight.w700,
              height: 1,
              color: colors.onPrimary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _specialDayStatus(
    DateTime date,
    TimeService timeService,
    String language,
    bool showEthiopic,
  ) {
    final colors = Theme.of(context).colorScheme;
    final observance = _observances.forDate(
      date,
      timeService,
      language: language,
    );
    final hasObservance = observance.isFeast || observance.isFast;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outline.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedText(language, 'የቀኑ ልዩ ሁኔታ', 'Day observances'),
                  style: GoogleFonts.cinzel(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                if (observance.isFeast)
                  _observanceChip(
                    observance.feast!,
                    AppColors.gold,
                  ),
                if (observance.isFast) ...[
                  if (observance.isFeast) const SizedBox(height: 6),
                  _observanceChip(
                    observance.fast!,
                    AppColors.terracotta,
                  ),
                ],
                if (!hasObservance)
                  Text(
                    localizedText(
                      language,
                      'በዚህ ቀን የተመዘገበ በዓል ወይም የሳምንት ጾም የለም።',
                      'No feast or regular weekly fast is listed for this day.',
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                if (showEthiopic)
                  Text(
                    timeService.formatEthiopianDateFor(
                      date,
                      language: language,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: colors.onSurface.withValues(alpha: 0.56),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthButton(IconData icon, int monthOffset, TimeService timeService) {
    final colors = Theme.of(context).colorScheme;
    final isLightAppearance = colors.brightness == Brightness.light;
    return IconButton(
      icon: Icon(
        icon,
        size: isLightAppearance ? 20 : 18,
        color: isLightAppearance
            ? AppColors.terracotta
            : AppColors.gold.withValues(alpha: 0.7),
      ),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: isLightAppearance ? 40 : 28,
        minHeight: isLightAppearance ? 40 : 28,
      ),
      style: isLightAppearance
          ? IconButton.styleFrom(
              backgroundColor: AppColors.warmCream,
              shape: const CircleBorder(),
            )
          : null,
      onPressed: () =>
          setState(() => _shiftVisibleMonth(monthOffset, timeService)),
    );
  }

  void _shiftVisibleMonth(int offset, TimeService timeService) {
    if (!_showEth) {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
      return;
    }

    final current = timeService.toEthiopian(_visibleMonth);
    var year = current.year;
    var month = current.month + offset;
    if (month < 1) {
      month = 13;
      year--;
    } else if (month > 13) {
      month = 1;
      year++;
    }
    _visibleMonth = timeService.toGregorian(
      EthiopianDate(year: year, month: month, day: 1),
    );
  }

  DateTime _monthForDisplay(
    DateTime date,
    TimeService timeService,
    bool ethiopic,
  ) {
    if (!ethiopic) return _monthStart(date);
    final ethiopian = timeService.toEthiopian(date);
    return timeService.toGregorian(
      EthiopianDate(year: ethiopian.year, month: ethiopian.month, day: 1),
    );
  }

  void _shiftVisibleYear(int offset, TimeService timeService) {
    if (!_showEth) {
      _visibleMonth = DateTime(
        _visibleMonth.year + offset,
        _visibleMonth.month,
      );
      return;
    }
    final current = timeService.toEthiopian(_visibleMonth);
    _visibleMonth = timeService.toGregorian(
      EthiopianDate(
        year: current.year + offset,
        month: current.month,
        day: 1,
      ),
    );
  }

  Future<void> _pickDate(CalendarProvider calendar, String language) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: calendar.selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      helpText: localizedText(language, 'ቀን ይምረጡ', 'Go to date'),
    );
    if (picked == null || !mounted) return;
    calendar.selectDate(picked);
    setState(() {
      _visibleMonth = _monthForDisplay(
        picked,
        ref.read(timeServiceProvider),
        _showEth,
      );
    });
  }

  Widget _buildWeek(
    List<int?> days, {
    required DateTime selectedDate,
    required DateTime today,
    required DateTime Function(int day) dateForDay,
    required TimeService timeService,
    required String language,
  }) {
    return Row(
      children: days.map((day) {
        if (day == null) return const Expanded(child: SizedBox.shrink());
        final date = dateForDay(day);
        final isSelected = CalendarProvider.isSameDate(date, selectedDate);
        final isToday = CalendarProvider.isSameDate(date, today);
        final observance = _observances.forDate(
          date,
          timeService,
          language: language,
        );
        final colors = Theme.of(context).colorScheme;
        final isLightAppearance = colors.brightness == Brightness.light;
        return Expanded(
          child: Semantics(
            button: true,
            selected: isSelected,
            label: [
              '${date.year}-${date.month}-${date.day}',
              if (observance.feast != null) observance.feast!,
              if (observance.fast != null) observance.fast!,
            ].join(', '),
            child: GestureDetector(
              onTap: () => ref.read(calendarProvider).selectDate(date),
              child: Container(
                height: isLightAppearance ? 44 : 36,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isSelected)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: isLightAppearance ? 38 : 30,
                        height: isLightAppearance ? 38 : 30,
                        decoration: BoxDecoration(
                          shape: isLightAppearance
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                          borderRadius: isLightAppearance
                              ? BorderRadius.circular(12)
                              : null,
                          color:
                              (isLightAppearance
                                      ? AppColors.terracotta
                                      : colors.primary)
                                  .withValues(
                                    alpha: isLightAppearance ? 1 : 0.85,
                                  ),
                          border: Border.all(
                            color: isLightAppearance
                                ? AppColors.terracotta
                                : colors.secondary,
                            width: 1.5,
                          ),
                          boxShadow: isLightAppearance
                              ? [
                                  BoxShadow(
                                    color: AppColors.terracotta.withValues(
                                      alpha: 0.22,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: colors.secondary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 10,
                                  ),
                                ],
                        ),
                      ),
                    if (isToday && !isSelected)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: isLightAppearance ? 38 : 30,
                        height: isLightAppearance ? 38 : 30,
                        decoration: BoxDecoration(
                          shape: isLightAppearance
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                          borderRadius: isLightAppearance
                              ? BorderRadius.circular(12)
                              : null,
                          border: Border.all(
                            color: isLightAppearance
                                ? AppColors.terracotta
                                : colors.secondary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    if (!isSelected && !isToday &&
                        (observance.isFeast || observance.isFast))
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: isLightAppearance ? 36 : 30,
                        height: isLightAppearance ? 36 : 30,
                        decoration: BoxDecoration(
                          color: observance.isFeast && observance.isFast
                              ? colors.primaryContainer.withValues(alpha: 0.62)
                              : (observance.isFeast
                                        ? AppColors.gold
                                        : AppColors.terracotta)
                                    .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            isLightAppearance ? 12 : 50,
                          ),
                        ),
                      ),
                    if (observance.isFeast || observance.isFast)
                      Positioned(
                        bottom: 2,
                        child: SizedBox(
                          width: 18,
                          child: Row(
                            children: [
                              if (observance.isFeast)
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: AppColors.goldDim,
                                  ),
                                ),
                              if (observance.isFast)
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: AppColors.terracotta,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    Text(
                      '$day',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isSelected
                            ? (isLightAppearance
                                  ? Colors.white
                                  : colors.onPrimary)
                            : colors.onSurface.withValues(alpha: 0.75),
                        fontWeight: isSelected || isToday
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _legendItem(String label, Color color) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: colors.onSurface.withValues(alpha: 0.78),
        ),
      ),
    );
  }

  Widget _upcomingWeek(
    DateTime today,
    TimeService timeService,
    String language,
    CalendarProvider calendar,
  ) {
    final colors = Theme.of(context).colorScheme;
    final todayStart = DateTime(today.year, today.month, today.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              localizedText(language, 'የሚቀጥሉት 7 ቀናት', 'Coming up'),
              style: GoogleFonts.cinzel(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              localizedText(language, '· 7 ቀናት', '· next 7 days'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 106,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final date = todayStart.add(Duration(days: index + 1));
              final observance = _observances.forDate(
                date,
                timeService,
                language: language,
              );
              const weekdaysAm = ['ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ', 'እሑድ'];
              final hasSpecial = observance.isFeast || observance.isFast;
              final markerColor = observance.isFeast
                  ? AppColors.gold
                  : AppColors.terracotta;
              return SizedBox(
                width: 122,
                child: Material(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      calendar.selectDate(date);
                      setState(() {
                        _visibleMonth = _monthForDisplay(
                          date,
                          timeService,
                          _showEth,
                        );
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasSpecial
                              ? markerColor.withValues(alpha: 0.42)
                              : colors.outlineVariant.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            language == 'eth'
                                ? weekdaysAm[date.weekday - 1]
                                : DateFormat('EEE').format(date),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            timeService.formatGregorianDate(date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.ebGaramond(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          const Spacer(),
                          if (observance.isFeast)
                            _upcomingMarker(observance.feast!, AppColors.goldDim),
                          if (observance.isFast)
                            _upcomingMarker(observance.fast!, AppColors.terracotta),
                          if (!hasSpecial)
                            Text(
                              localizedText(language, 'ልዩ ቀን የለም', 'No observance'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _upcomingMarker(String label, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 9,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _observanceChip(String label, Color color) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: colors.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _prayerHoursForDate(
    DateTime selectedDate,
    DateTime today,
    String language,
    PrayerProvider prayer,
    TimeService timeService,
  ) {
    final colors = Theme.of(context).colorScheme;
    final key = _dateKey(selectedDate);
    final completed = prayer.history[key] ?? const <bool>[];
    final isToday = CalendarProvider.isSameDate(selectedDate, today);
    final progress = completed.where((value) => value).length;
    final occurrences = timeService.prayerOccurrencesFor(selectedDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizedText(language, 'የጸሎት ሰዓታት', 'Prayer hours'),
                style: GoogleFonts.cinzel(fontSize: 13, color: colors.primary),
              ),
              Text(
                '$progress / ${hours.length}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...hours.asMap().entries.map((entry) {
            final index = entry.key;
            final hour = entry.value;
            final done = index < completed.length && completed[index];
            var label = localizedText(language, 'ያልተጠናቀቀ', 'Pending');
            var icon = Icons.radio_button_unchecked;
            if (done) {
              label = localizedText(language, 'ተጠናቋል', 'Completed');
              icon = Icons.check_circle_outline;
            } else if (isToday && occurrences.isNotEmpty) {
              final occurrence = occurrences.firstWhere(
                (item) => item.prayerHour.readerIndex == hour.id,
              );
              final status = timeService.prayerStatus(occurrence, today);
              if (status == PrayerStatus.current) {
                label = localizedText(language, 'አሁን', 'Current');
                icon = Icons.radio_button_checked;
              } else if (status == PrayerStatus.completed) {
                label = localizedText(language, 'ያመለጠ', 'Missed');
                icon = Icons.error_outline;
              } else if (status == PrayerStatus.upcoming) {
                label = localizedText(language, 'ቀጣይ', 'Upcoming');
                icon = Icons.schedule_outlined;
              }
            }
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, size: 20, color: colors.primary),
              title: Text(
                localizedText(language, hour.eth, hour.en),
                style: GoogleFonts.notoSansEthiopic(fontSize: 13),
              ),
              subtitle: Text(hour.time),
              trailing: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: colors.onSurface.withValues(alpha: 0.58),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Widget _selectedDayCard(
    DateTime selectedDate,
    DateTime today,
    TimeService timeService,
    String language,
    bool showEthiopic,
  ) {
    final colors = Theme.of(context).colorScheme;
    final isLightAppearance = colors.brightness == Brightness.light;
    final ethiopianDate = timeService.toEthiopian(selectedDate);
    final isToday = CalendarProvider.isSameDate(selectedDate, today);
    final dayOffset = DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isLightAppearance ? 24 : 12),
        color: (isLightAppearance ? AppColors.warmCream : colors.primary)
            .withValues(alpha: isLightAppearance ? 1 : 0.08),
        border: Border.all(
          color: (isLightAppearance ? AppColors.terracotta : colors.primary)
              .withValues(alpha: isLightAppearance ? 0.16 : 0.22),
        ),
        boxShadow: isLightAppearance
            ? [
                BoxShadow(
                  color: AppColors.terracotta.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const EthCross(size: 16, opacity: 0.8),
              const SizedBox(width: 8),
              Text(
                showEthiopic
                    ? '${language == 'eth' ? ethMonths[ethiopianDate.month - 1] : ethMonthsEnglish[ethiopianDate.month - 1]} ${ethiopianDate.day}, ${ethiopianDate.year}'
                    : timeService.formatGregorianDate(selectedDate),
                style: showEthiopic
                    ? GoogleFonts.notoSansEthiopic(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      )
                    : GoogleFonts.ebGaramond(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
              ),
              const SizedBox(width: 8),
              Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: (isToday ? AppColors.gold : colors.primary).withValues(alpha: 0.12),
                    border: Border.all(
                      color: (isToday ? AppColors.gold : colors.primary).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    isToday
                        ? localizedText(language, 'ዛሬ', 'TODAY')
                        : dayOffset > 0
                        ? localizedText(language, 'ወደፊት', 'UPCOMING')
                        : localizedText(language, 'ያለፈ', 'PAST'),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: isToday ? AppColors.goldDim : colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (showEthiopic)
            Text(
              timeService.formatGregorianDate(selectedDate),
              style: GoogleFonts.ebGaramond(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.68),
              ),
            ),
        ],
      ),
    );
  }

  DateTime _ethiopianMonthStart(int year, int month, TimeService timeService) {
    return timeService.toGregorian(
      EthiopianDate(year: year, month: month, day: 1),
    );
  }

  int _ethiopianDaysInMonth(int year, int month, TimeService timeService) {
    if (month != 13) return 30;
    try {
      timeService.toGregorian(EthiopianDate(year: year, month: month, day: 6));
      return 6;
    } on ArgumentError {
      return 5;
    }
  }
}
