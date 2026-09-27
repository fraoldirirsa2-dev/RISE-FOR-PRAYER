import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:rise_for_prayer/utils/constants.dart';
import 'package:rise_for_prayer/utils/localization.dart';

/// Counts and saves Metania independently for each prayer hour/day.
class MetaniaCounter extends ConsumerStatefulWidget {
  const MetaniaCounter({
    super.key,
    required this.prayerHourId,
    this.enabled = true,
    this.initialCount = AppConstants.defaultMetaniaCount,
  });

  final int prayerHourId;
  final bool enabled;
  final int initialCount;

  @override
  ConsumerState<MetaniaCounter> createState() => _MetaniaCounterState();
}

class _MetaniaCounterState extends ConsumerState<MetaniaCounter> {
  int _count = 0;
  bool _loaded = false;
  bool _isAutoCounting = false;
  Timer? _autoTimer;
  late final String _storageKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _storageKey = 'metania_${now.year}-${now.month}-${now.day}_${widget.prayerHourId}';
    _loadCount();
  }

  Future<void> _loadCount() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _count = preferences.getInt(_storageKey) ?? 0;
      _loaded = true;
    });
  }

  Future<void> _setCount(int value) async {
    if (!widget.enabled) return;
    final next = value.clamp(0, widget.initialCount).toInt();
    setState(() => _count = next);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_storageKey, next);
  }

  Future<void> _increment({bool haptic = true}) async {
    if (!widget.enabled || !_loaded || _count >= widget.initialCount) return;
    if (haptic) await HapticFeedback.selectionClick();
    await _setCount(_count + 1);
    if (_count >= widget.initialCount) _stopAutoCount();
  }

  void _startAutoCount() {
    if (!widget.enabled || !_loaded || _count >= widget.initialCount || _isAutoCounting) return;
    setState(() => _isAutoCounting = true);
    _autoTimer = Timer.periodic(AppConstants.metaniaInterval, (_) {
      if (!mounted) return;
      _increment(haptic: false);
    });
  }

  void _stopAutoCount() {
    _autoTimer?.cancel();
    _autoTimer = null;
    if (_isAutoCounting && mounted) {
      setState(() => _isAutoCounting = false);
    }
  }

  Future<void> _confirmReset(String language) async {
    if (!widget.enabled) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizedText(language, 'ዳግም ጀምር?', 'Reset this count?')),
        content: Text(localizedText(
          language,
          'የዚህ የጸሎት ሰዓት ስግደት ቁጥር ወደ ዜሮ ይመለሳል።',
          'This prayer hour’s Metania count will return to zero.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizedText(language, 'ሰርዝ', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localizedText(language, 'ዳግም ጀምር', 'Reset')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _stopAutoCount();
      await _setCount(0);
    }
  }

  @override
  void didUpdateWidget(covariant MetaniaCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _autoTimer?.cancel();
      _autoTimer = null;
      _isAutoCounting = false;
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(settingsProvider).language;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final progress = widget.initialCount <= 0
        ? 0.0
        : (_count / widget.initialCount).clamp(0.0, 1.0).toDouble();
    final complete = _count >= widget.initialCount;
    final locked = !widget.enabled;
    final title = localizedText(language, 'ስግደት', 'Metania');
    final hint = localizedText(
      language,
      'ከእያንዳንዱ ስግደት በኋላ ክብሉን ይንኩ።',
      'Tap the circle once after each prostration.',
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface,
            Color.lerp(colors.surface, colors.primary, 0.06)!,
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(hint, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              TextButton(
                onPressed: locked || !_loaded || _count == 0
                    ? null
                    : () => _confirmReset(language),
                child: Text(localizedText(language, 'ዳግም ጀምር', 'Reset')),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Column(
            children: [
              Semantics(
                    button: true,
                    label: '$title, $_count / ${widget.initialCount}',
                    hint: hint,
                    child: GestureDetector(
                    onTap: locked || !_loaded || complete ? null : _increment,
                      child: SizedBox(
                        width: 156,
                        height: 156,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 8,
                                strokeCap: StrokeCap.round,
                                backgroundColor:
                                    colors.primary.withValues(alpha: 0.12),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: 138,
                              height: 138,
                              decoration: BoxDecoration(
                                color: complete
                                    ? colors.primary.withValues(alpha: 0.12)
                                    : colors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 160),
                                    transitionBuilder: (child, animation) =>
                                        ScaleTransition(
                                          scale: animation,
                                          child: child,
                                        ),
                                    child: Text(
                                      _loaded ? '$_count' : '—',
                                      key: ValueKey(_count),
                                      style: GoogleFonts.inter(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w700,
                                        color: complete
                                            ? colors.primary
                                            : colors.onPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    complete
                                        ? localizedText(language, 'ጨርሰዋል', 'Goal reached')
                                        : localizedText(language, 'ከ ${widget.initialCount}', 'of ${widget.initialCount}'),
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: complete
                                          ? colors.primary
                                          : colors.onPrimary.withValues(
                                              alpha: 0.82,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: locked || !_loaded || _count == 0
                    ? null
                    : () => _setCount(_count - 1),
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: Text(localizedText(language, 'አንድ ቀንስ', 'Undo last count')),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            locked
                ? localizedText(language, 'የጸሎት ሰዓቱ ሲደርስ ይከፈታል', 'Locked until prayer time')
                : !_loaded
                ? localizedText(language, 'በመጫን ላይ…', 'Loading…')
                : complete
                    ? localizedText(language, 'የዚህ ሰዓት ግብ ተሟልቷል', 'Prayer hour goal complete')
                    : localizedText(
                        language,
                        'ቀሪ: ${widget.initialCount - _count}',
                        '${widget.initialCount - _count} remaining',
                      ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: complete ? colors.primary : colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: locked || !_loaded || complete
                  ? null
                  : _isAutoCounting
                      ? _stopAutoCount
                      : _startAutoCount,
              icon: Icon(
                _isAutoCounting ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(
                _isAutoCounting
                    ? localizedText(language, 'ቆጠራውን አቁም', 'Pause auto count')
                    : localizedText(language, 'ራስ-ሰር ቁጠር', 'Start auto count'),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            locked
                ? localizedText(
                    language,
                    'የስግደት ቆጠራ የጸሎት ሰዓቱ ሲደርስ ይከፈታል።',
                    'Metania counting unlocks when this prayer hour begins.',
                  )
                : localizedText(
                    language,
                    'ራስ-ሰር ቆጠራው በየ2 ሰከንዱ አንድ ይጨምራል። በማንኛውም ጊዜ ማቆም ይችላሉ።',
                    'Auto count adds one every 2 seconds. You can pause at any time.',
                  ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: colors.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
