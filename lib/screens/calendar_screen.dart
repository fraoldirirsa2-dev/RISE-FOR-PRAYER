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

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static const _observances = EthiopianObservanceService();
  bool _showEth = true;
  DateTime _visibleMonth = _monthStart(TimeService.currentNow());
  String? _scheduledTodaySync;

  static DateTime _monthStart(DateTime date) => DateTime(date.year, date.month);

  @override
  void initState() {
    super.initState();
    final timeService = ref.read(timeServiceProvider);
    _visibleMonth = _monthForDisplay(timeService.now, timeService, _showEth);
  }

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

    return Scaffold(
      backgroundColor: background,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'የቀን መቁጠሪያ',
                    style: GoogleFonts.notoSansEthiopic(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    'Calendar',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: SafeArea(
        top: widget.embedded,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.embedded) _calendarHeader(settings.language),
                  _calendarModeSwitcher(
                    settings.language,
                    calendar,
                    timeService,
                  ),
                  const SizedBox(height: 12),
                  _todaySummary(
                    today,
                    selectedDate,
                    timeService,
                    settings.language,
                    _showEth,
                  ),
                  const SizedBox(height: 20),
                  _monthNavigator(
                    calendar: calendar,
                    timeService: timeService,
                    language: settings.language,
                    monthTitle: _showEth
                        ? (settings.language == 'eth'
                              ? ethMonths[displayedEthiopianMonth - 1]
                              : ethMonthsEnglish[displayedEthiopianMonth - 1])
                        : DateFormat('MMMM').format(_visibleMonth),
                    yearTitle: _showEth
                        ? '$displayedEthiopianYear ${localizedText(settings.language, 'ዓ.ም', 'E.C.').trim()}'
                        : '${_visibleMonth.year}',
                  ),
                  const SizedBox(height: 12),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final calendarColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _calendarMonthGrid(
                            leadingDays: leadingDays,
                            daysInMonth: daysInMonth,
                            selectedDate: selectedDate,
                            today: today,
                            dateForDay: dateForDay,
                            timeService: timeService,
                            language: settings.language,
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 14,
                            runSpacing: 8,
                            children: [
                              _legendItem(
                                localizedText(settings.language, 'ዛሬ', 'Today'),
                                colors.secondary,
                                outlined: true,
                              ),
                              _legendItem(
                                localizedText(
                                  settings.language,
                                  'ተመርጧል',
                                  'Selected',
                                ),
                                colors.primary,
                              ),
                              _legendItem(
                                localizedText(
                                  settings.language,
                                  'በዓል',
                                  'Feast',
                                ),
                                AppColors.goldDim,
                              ),
                              _legendItem(
                                localizedText(settings.language, 'ጾም', 'Fast'),
                                AppColors.terracotta,
                              ),
                            ],
                          ),
                        ],
                      );
                      final selectedDetails = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                          ),
                          const SizedBox(height: 16),
                          _prayerHoursForDate(
                            selectedDate,
                            today,
                            settings.language,
                            prayer,
                            timeService,
                          ),
                        ],
                      );
                      if (constraints.maxWidth >= 960) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: calendarColumn),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: selectedDetails),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          calendarColumn,
                          const SizedBox(height: 18),
                          selectedDetails,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _upcomingWeek(
                    today,
                    timeService,
                    settings.language,
                    calendar,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _calendarHeader(String language) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'የቀን መቁጠሪያ',
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  'Calendar',
                  style: GoogleFonts.ebGaramond(
                    fontSize: 17,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const EthCross(size: 22, opacity: 0.75),
        ],
      ),
    );
  }

  Widget _calendarModeSwitcher(
    String language,
    CalendarProvider calendar,
    TimeService timeService,
  ) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: SegmentedButton<bool>(
      segments: [
        ButtonSegment(
          value: true,
          label: Text(localizedText(language, 'ኢትዮጵያዊ', 'Ethiopian')),
        ),
        ButtonSegment(
          value: false,
          label: Text(localizedText(language, 'ግሪጎሪያን', 'Gregorian')),
        ),
      ],
      selected: {_showEth},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        final isEthiopian = selection.first;
        final selected = calendar.selectedDate;
        setState(() {
          _showEth = isEthiopian;
          _visibleMonth = _monthForDisplay(selected, timeService, isEthiopian);
        });
      },
    ),
  );

  Widget _monthNavigator({
    required CalendarProvider calendar,
    required TimeService timeService,
    required String language,
    required String monthTitle,
    required String yearTitle,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    monthTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _showEth && language == 'eth'
                        ? GoogleFonts.notoSansEthiopic(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          )
                        : GoogleFonts.ebGaramond(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                  ),
                  Text(
                    yearTitle,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            _monthButton(Icons.chevron_left, -1, timeService),
            IconButton(
              tooltip: localizedText(language, 'ዛሬ', 'Today'),
              icon: const Icon(Icons.today_outlined),
              onPressed: () {
                calendar.selectToday();
                final today = timeService.now;
                setState(() {
                  _visibleMonth = _monthForDisplay(
                    today,
                    timeService,
                    _showEth,
                  );
                });
              },
            ),
            _monthButton(Icons.chevron_right, 1, timeService),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            children: [
              IconButton(
                tooltip: localizedText(language, 'ዓመት ወደ ኋላ', 'Previous year'),
                icon: const Icon(Icons.keyboard_double_arrow_left),
                onPressed: () =>
                    setState(() => _shiftVisibleYear(-1, timeService)),
              ),
              Text(
                localizedText(language, 'ዓመት', 'Year'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              IconButton(
                tooltip: localizedText(language, 'ዓመት ወደ ፊት', 'Next year'),
                icon: const Icon(Icons.keyboard_double_arrow_right),
                onPressed: () =>
                    setState(() => _shiftVisibleYear(1, timeService)),
              ),
              TextButton.icon(
                onPressed: () => _pickDate(calendar, language),
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(localizedText(language, 'ቀን ይምረጡ', 'Go to date')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _todaySummary(
    DateTime today,
    DateTime selectedDate,
    TimeService timeService,
    String language,
    bool showEthiopic,
  ) {
    final colors = Theme.of(context).colorScheme;
    final selectedIsToday = CalendarProvider.isSameDate(today, selectedDate);
    const weekdaysAmharic = ['እሑድ', 'ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ'];
    final primaryDate = showEthiopic
        ? timeService.formatEthiopianDateFor(today, language: language)
        : timeService.formatGregorianDate(today);
    final secondaryDate = showEthiopic
        ? timeService.formatGregorianDate(today)
        : timeService.formatEthiopianDateFor(today, language: language);
    final weekday = language == 'eth'
        ? weekdaysAmharic[today.weekday % 7]
        : DateFormat('EEEE').format(today);
    final selectedLabel = showEthiopic
        ? timeService.formatEthiopianDateFor(selectedDate, language: language)
        : timeService.formatGregorianDate(selectedDate);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.today_outlined, color: colors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedText(language, 'ዛሬ', 'Today'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  primaryDate,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: showEthiopic
                      ? GoogleFonts.notoSansEthiopic(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                          height: 1.35,
                        )
                      : GoogleFonts.ebGaramond(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                ),
                Text(
                  '$weekday · $secondaryDate',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                if (!selectedIsToday) ...[
                  const SizedBox(height: 7),
                  Text(
                    '${localizedText(language, 'የተመረጠው ቀን', 'Viewing')}: $selectedLabel',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.primary),
                  ),
                ],
              ],
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
  ) {
    final colors = Theme.of(context).colorScheme;
    final observance = _observances.forDate(
      date,
      timeService,
      language: language,
    );
    final hasObservance = observance.isFeast || observance.isFast;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizedText(language, 'የቀኑ ልዩ ሁኔታ', 'Day observances'),
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(color: colors.onSurface, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (hasObservance)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (observance.isFeast)
                _observanceChip(
                  localizedText(language, 'በዓል', 'Feast'),
                  observance.feast!,
                  AppColors.goldDim,
                  Icons.star_outline,
                ),
              if (observance.isFast)
                _observanceChip(
                  localizedText(language, 'ጾም', 'Fast'),
                  observance.fast!,
                  AppColors.terracotta,
                  Icons.schedule_outlined,
                ),
            ],
          )
        else
          Text(
            localizedText(
              language,
              'በዚህ ቀን የተመዘገበ በዓል ወይም የሳምንት ጾም የለም።',
              'No listed feast or regular weekly fast.',
            ),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _monthButton(IconData icon, int monthOffset, TimeService timeService) {
    final colors = Theme.of(context).colorScheme;
    final language = ref.watch(settingsProvider).language;
    return IconButton(
      icon: Icon(icon, size: 22, color: colors.primary),
      tooltip: localizedText(
        language,
        monthOffset < 0 ? 'ወር ወደ ኋላ' : 'ወር ወደ ፊት',
        monthOffset < 0 ? 'Previous month' : 'Next month',
      ),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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
      EthiopianDate(year: current.year + offset, month: current.month, day: 1),
    );
  }

  Future<void> _pickDate(CalendarProvider calendar, String language) async {
    final timeService = ref.read(timeServiceProvider);
    final picked = _showEth
        ? await _pickEthiopianDate(calendar.selectedDate, timeService, language)
        : await showDatePicker(
            context: context,
            initialDate: calendar.selectedDate,
            firstDate: DateTime(1900),
            lastDate: DateTime(2200),
            helpText: localizedText(language, 'ቀን ይምረጡ', 'Go to date'),
          );
    if (picked == null || !mounted) return;
    calendar.selectDate(picked);
    setState(() {
      _visibleMonth = _monthForDisplay(picked, timeService, _showEth);
    });
  }

  Future<DateTime?> _pickEthiopianDate(
    DateTime selectedDate,
    TimeService timeService,
    String language,
  ) async {
    final initial = timeService.toEthiopian(selectedDate);
    var year = initial.year;
    var month = initial.month;
    var day = initial.day;
    final yearController = TextEditingController(text: '$year');
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final parsedYear = int.tryParse(yearController.text.trim());
          final yearIsValid = parsedYear != null && parsedYear > 0;
          final monthDays = _ethiopianDaysInMonth(year, month, timeService);
          if (day > monthDays) day = monthDays;
          final equivalentDate = yearIsValid
              ? timeService.toGregorian(
                  EthiopianDate(year: year, month: month, day: day),
                )
              : null;
          return AlertDialog(
            title: Text(
              localizedText(
                language,
                'የኢትዮጵያ ቀን ይምረጡ',
                'Choose Ethiopian date',
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: month,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: localizedText(language, 'ወር', 'Month'),
                    ),
                    items: [
                      for (var monthIndex = 1; monthIndex <= 13; monthIndex++)
                        DropdownMenuItem(
                          value: monthIndex,
                          child: Text(
                            language == 'eth'
                                ? ethMonths[monthIndex - 1]
                                : ethMonthsEnglish[monthIndex - 1],
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        month = value;
                        final maxDay = _ethiopianDaysInMonth(
                          year,
                          month,
                          timeService,
                        );
                        if (day > maxDay) day = maxDay;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: yearController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: localizedText(language, 'ዓመት', 'Year'),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        final parsed = int.tryParse(value.trim());
                        if (parsed != null && parsed > 0) {
                          year = parsed;
                          final maxDay = _ethiopianDaysInMonth(
                            year,
                            month,
                            timeService,
                          );
                          if (day > maxDay) day = maxDay;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: day,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: localizedText(language, 'ቀን', 'Day'),
                    ),
                    items: [
                      for (var dayIndex = 1; dayIndex <= monthDays; dayIndex++)
                        DropdownMenuItem(
                          value: dayIndex,
                          child: Text('$dayIndex'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => day = value);
                      }
                    },
                  ),
                  if (equivalentDate != null) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '${localizedText(language, 'በግሪጎሪያን', 'Gregorian equivalent')}: ${timeService.formatGregorianDate(equivalentDate)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(localizedText(language, 'ይቅር', 'Cancel')),
              ),
              FilledButton(
                onPressed: yearIsValid
                    ? () => Navigator.pop(
                        dialogContext,
                        timeService.toGregorian(
                          EthiopianDate(year: year, month: month, day: day),
                        ),
                      )
                    : null,
                child: Text(localizedText(language, 'ምረጥ', 'Select date')),
              ),
            ],
          );
        },
      ),
    );
    yearController.dispose();
    return picked;
  }

  Widget _calendarMonthGrid({
    required int leadingDays,
    required int daysInMonth,
    required DateTime selectedDate,
    required DateTime today,
    required DateTime Function(int day) dateForDay,
    required TimeService timeService,
    required String language,
  }) {
    final colors = Theme.of(context).colorScheme;
    final weekdays = _showEth && language == 'eth' ? weekEth : weekGreg;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final weekday in weekdays)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      weekday,
                      textAlign: TextAlign.center,
                      style: language == 'eth'
                          ? GoogleFonts.notoSansEthiopic(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurfaceVariant,
                            )
                          : Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
            ],
          ),
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
              language: language,
            ),
        ],
      ),
    );
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
        final isPast = DateTime(
          date.year,
          date.month,
          date.day,
        ).isBefore(DateTime(today.year, today.month, today.day));
        final observance = _observances.forDate(
          date,
          timeService,
          language: language,
        );
        final colors = Theme.of(context).colorScheme;
        const weekdaysAmharic = [
          'እሑድ',
          'ሰኞ',
          'ማክሰኞ',
          'ረቡዕ',
          'ሐሙስ',
          'ዓርብ',
          'ቅዳሜ',
        ];
        final dateLabel = _showEth
            ? timeService.formatEthiopianDateFor(date, language: language)
            : timeService.formatGregorianDate(date);
        final weekdayLabel = language == 'eth'
            ? weekdaysAmharic[date.weekday % 7]
            : DateFormat('EEEE').format(date);
        final semanticParts = [
          weekdayLabel,
          dateLabel,
          if (isToday) localizedText(language, 'ዛሬ', 'Today'),
          if (isSelected) localizedText(language, 'ተመርጧል', 'Selected'),
          if (observance.feast != null) observance.feast!,
          if (observance.fast != null) observance.fast!,
        ];
        return Expanded(
          child: Semantics(
            button: true,
            selected: isSelected,
            label: semanticParts.join(', '),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => ref.read(calendarProvider).selectDate(date),
                child: SizedBox(
                  height: 52,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 36,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: isToday
                                ? colors.secondary
                                : isSelected
                                ? colors.primary
                                : Colors.transparent,
                            width: isToday || isSelected ? 1.5 : 0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$day',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isToday || isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? colors.onPrimary
                                : colors.onSurface.withValues(
                                    alpha: isPast ? 0.72 : 0.92,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        height: 5,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (observance.isFeast)
                              _observanceDot(AppColors.goldDim),
                            if (observance.isFeast && observance.isFast)
                              const SizedBox(width: 3),
                            if (observance.isFast)
                              _observanceDot(AppColors.terracotta),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _observanceDot(Color color) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _legendItem(String label, Color color, {bool outlined = false}) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: outlined ? Colors.transparent : color,
                border: Border.all(color: color, width: 1.5),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurface.withValues(alpha: 0.82)),
            ),
          ],
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
    const weekdaysAmharic = ['እሑድ', 'ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizedText(language, 'የሚቀጥሉት 7 ቀናት', 'Coming up'),
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final date = todayStart.add(Duration(days: index + 1));
              final observance = _observances.forDate(
                date,
                timeService,
                language: language,
              );
              final ethiopianDate = timeService.toEthiopian(date);
              final weekdayLabel = language == 'eth'
                  ? weekdaysAmharic[date.weekday % 7]
                  : DateFormat('EEE').format(date);
              final monthLabel = _showEth
                  ? (language == 'eth'
                        ? ethMonths[ethiopianDate.month - 1]
                        : ethMonthsEnglish[ethiopianDate.month - 1])
                  : DateFormat('MMM').format(date);
              final dayNumber = _showEth ? ethiopianDate.day : date.day;
              final activeDateLabel = _showEth
                  ? timeService.formatEthiopianDateFor(date, language: language)
                  : timeService.formatGregorianDate(date);
              final observanceLabel = [
                if (observance.feast != null) observance.feast!,
                if (observance.fast != null) observance.fast!,
              ].join(', ');
              final semanticLabel = [
                weekdayLabel,
                activeDateLabel,
                if (observanceLabel.isNotEmpty) observanceLabel,
              ].join(', ');
              return SizedBox(
                width: 68,
                child: Semantics(
                  button: true,
                  label: semanticLabel,
                  child: ExcludeSemantics(
                    child: Tooltip(
                      message: observanceLabel.isEmpty
                          ? activeDateLabel
                          : '$activeDateLabel\n$observanceLabel',
                      child: Material(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
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
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  weekdayLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                                Text(
                                  '$dayNumber',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: colors.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                Text(
                                  monthLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 3),
                                SizedBox(
                                  height: 5,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (observance.isFeast)
                                        _observanceDot(AppColors.goldDim),
                                      if (observance.isFeast &&
                                          observance.isFast)
                                        const SizedBox(width: 3),
                                      if (observance.isFast)
                                        _observanceDot(AppColors.terracotta),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Widget _observanceChip(
    String type,
    String label,
    Color color,
    IconData icon,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Text(
            type,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$progress / ${hours.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: localizedText(
              language,
              'ከ${hours.length} የጸሎት ሰዓታት ውስጥ $progress ተጠናቋል',
              '$progress of ${hours.length} prayer hours completed',
            ),
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: progress / hours.length,
                  minHeight: 7,
                  color: colors.primary,
                  backgroundColor: colors.onSurface.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...hours.asMap().entries.map((entry) {
            final index = entry.key;
            final hour = entry.value;
            final done = index < completed.length && completed[index];
            var label = localizedText(language, 'ያልተጠናቀቀ', 'Pending');
            var icon = Icons.radio_button_unchecked;
            var statusColor = colors.onSurfaceVariant;
            if (done) {
              label = localizedText(language, 'ተጠናቋል', 'Completed');
              icon = Icons.check_circle_outline;
              statusColor = colors.primary;
            } else if (isToday && occurrences.isNotEmpty) {
              final occurrence = occurrences.firstWhere(
                (item) => item.prayerHour.readerIndex == hour.id,
              );
              final status = timeService.prayerStatus(occurrence, today);
              if (status == PrayerStatus.current) {
                label = localizedText(language, 'አሁን', 'Current');
                icon = Icons.radio_button_checked;
                statusColor = colors.secondary;
              } else if (status == PrayerStatus.completed) {
                label = localizedText(language, 'ያመለጠ', 'Missed');
                icon = Icons.error_outline;
                statusColor = colors.error;
              } else if (status == PrayerStatus.upcoming) {
                label = localizedText(language, 'ቀጣይ', 'Upcoming');
                icon = Icons.schedule_outlined;
                statusColor = colors.onSurfaceVariant;
              }
            }
            final hourName = localizedText(language, hour.eth, hour.en);
            return Semantics(
              label: '$hourName, $label, ${hour.time}',
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: statusColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hourName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: language == 'eth'
                                  ? GoogleFonts.notoSansEthiopic(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    )
                                  : GoogleFonts.ebGaramond(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                            ),
                            Text(
                              hour.time,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
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
    final isToday = CalendarProvider.isSameDate(selectedDate, today);
    final dayOffset = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    const weekdaysAmharic = ['እሑድ', 'ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ'];
    final primaryDate = showEthiopic
        ? timeService.formatEthiopianDateFor(selectedDate, language: language)
        : timeService.formatGregorianDate(selectedDate);
    final secondaryDate = showEthiopic
        ? timeService.formatGregorianDate(selectedDate)
        : timeService.formatEthiopianDateFor(selectedDate, language: language);
    final weekday = language == 'eth'
        ? weekdaysAmharic[selectedDate.weekday % 7]
        : DateFormat('EEEE').format(selectedDate);
    final statusLabel = isToday
        ? localizedText(language, 'ዛሬ', 'Today')
        : dayOffset > 0
        ? localizedText(language, 'ወደፊት', 'Upcoming')
        : localizedText(language, 'ያለፈ', 'Past');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                localizedText(language, 'የተመረጠው ቀን', 'Selected day'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(
                isToday ? Icons.today : Icons.circle_outlined,
                size: 16,
                color: isToday ? colors.secondary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                statusLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isToday ? colors.secondary : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            primaryDate,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: showEthiopic
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
            '$weekday · $secondaryDate',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
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
