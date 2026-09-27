import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:rise_for_prayer/utils/colors.dart';
import 'package:rise_for_prayer/utils/localization.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _current = 0;
  final List<Map<String, String>> _steps = const [
    {
      'titleEth': 'ሰባቱ የጸሎት ሰዓታት',
      'titleEn': 'Seven Daily Hours',
      'bodyEth': 'ከንጋት እስከ ሌሊት ድረስ ሰባቱን የጸሎት ሰዓታት ይከተሉ።',
      'bodyEn':
          'From Prime at dawn to Compline at night, pray the canonical hours.',
    },
    {
      'titleEth': 'የኢትዮጵያ ኦርቶዶክስ ቤተ ክርስቲያን',
      'titleEn': 'Ethiopian Orthodox Tewahedo',
      'bodyEth': 'በግዕዝ፣ በአማርኛ እና በእንግሊዝኛ ጸሎቶችን ይከተሉ።',
      'bodyEn': 'Prayers in Ge\'ez, Amharic, and English, with sacred Zema tradition.',
    },
    {
      'titleEth': 'የኢትዮጵያ ዘመን አቆጣጠር',
      'titleEn': 'Ethiopian Calendar & Fasts',
      'bodyEth': 'የጾም ቀናትንና የበዓላትን ቀን በኢትዮጵያ ዘመን ይከተሉ።',
      'bodyEn': 'Follow fasting days and feasts on the Ethiopian calendar.',
    },
  ];

  void _completeOnboarding() {
    ref.read(settingsProvider).setOnboardingComplete(true);
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_current];
    final language = ref.watch(settingsProvider).language;
    final isLast = _current == _steps.length - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0A0F), Color(0xFF0F172A), Color(0xFF0A0814)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.burgundy.withValues(alpha: 0.2),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: (_current == 0)
                        ? const Icon(
                            Icons.access_time,
                            size: 80,
                            color: AppColors.gold,
                          )
                        : (_current == 1)
                        ? const Icon(
                            Icons.menu_book,
                            size: 80,
                            color: AppColors.gold,
                          )
                        : const Icon(
                            Icons.calendar_month,
                            size: 80,
                            color: AppColors.gold,
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  localizedText(language, step['titleEth']!, step['titleEn']!),
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.parchment,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  localizedText(language, 'የዕለቱ መመሪያ', 'Daily Guide'),
                  style: GoogleFonts.cinzel(
                    fontSize: 11,
                    letterSpacing: 4,
                    color: AppColors.gold.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  localizedText(language, step['bodyEth']!, step['bodyEn']!),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ebGaramond(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: AppColors.parchment.withValues(alpha: 0.62),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _steps.length,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _current ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: i == _current
                            ? AppColors.gold
                            : AppColors.gold.withValues(alpha: 0.25),
                        boxShadow: i == _current
                            ? [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.45),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isLast) {
                        _completeOnboarding();
                      } else {
                        setState(() => _current++);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burgundyMid,
                      foregroundColor: AppColors.gold,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.35),
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isLast
                          ? localizedText(language, 'ጸሎቱን ጀምር', 'Begin Prayer')
                          : localizedText(language, 'ቀጥል', 'Continue'),
                      style: GoogleFonts.cinzel(
                        fontSize: 13,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      localizedText(language, 'ዝለል', 'Skip'),
                      style: TextStyle(
                        color: AppColors.gold.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                if (isLast)
                  TextButton(
                    onPressed: () {
                      if (_current > 0) {
                        setState(() => _current--);
                      }
                    },
                    child: Text(
                      localizedText(language, 'ቀዳሚ', 'Previous'),
                      style: TextStyle(
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
