import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rise_for_prayer/providers/app_providers.dart';
import 'package:rise_for_prayer/services/preferences_store.dart';
import 'package:rise_for_prayer/utils/colors.dart';
import 'package:rise_for_prayer/utils/localization.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 6500), _openNextScreen);
  }

  Future<void> _openNextScreen() async {
    if (!mounted) return;
    final prefs = await PreferencesStore.instance.preferences;
    if (!mounted) return;
    if (prefs.getBool('onboardingComplete') ?? false) {
      ref.read(settingsProvider).setOnboardingComplete(true);
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(settingsProvider).language;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0A0F), Color(0xFF0F172A), Color(0xFF0A0814)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 640;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: compact ? 112 : 132,
                          height: compact ? 112 : 132,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F6E8),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.7),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/splash.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(height: compact ? 18 : 24),
                        Text(
                          localizedText(
                            language,
                            'ለጸሎት ተነሱ',
                            'RISE FOR PRAYER',
                          ),
                          textAlign: TextAlign.center,
                          style: language == 'eth'
                              ? const TextStyle(
                                  fontFamily: 'AbyssinicaSIL',
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.parchment,
                                )
                              : GoogleFonts.cinzel(
                                  fontSize: compact ? 22 : 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3,
                                  color: AppColors.parchment,
                                  shadows: [
                                    Shadow(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 30,
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          localizedText(
                            language,
                            'የኦርቶዶክስ የዕለት ጸሎት መመሪያ',
                            'A daily guide to prayer and reflection',
                          ),
                          textAlign: TextAlign.center,
                          style: language == 'eth'
                              ? const TextStyle(
                                  fontFamily: 'AbyssinicaSIL',
                                  fontSize: 15,
                                  color: AppColors.goldLight,
                                )
                              : GoogleFonts.inter(
                                  fontSize: 13,
                                  letterSpacing: 0.3,
                                  color: AppColors.goldLight,
                                ),
                        ),
                        SizedBox(height: compact ? 22 : 30),
                        Container(
                          width: 120,
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.gold.withValues(alpha: 0.6),
                                AppColors.goldLight.withValues(alpha: 0.9),
                                AppColors.gold.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          localizedText(
                            language,
                            'ሰባት ጊዜ በቀን አንተን አመሰግናለሁ።',
                            'Seven times a day do I praise thee because of thy righteous judgments.',
                          ),
                          textAlign: TextAlign.center,
                          style: language == 'eth'
                              ? const TextStyle(
                                  fontFamily: 'AbyssinicaSIL',
                                  fontSize: 17,
                                  height: 1.65,
                                  color: AppColors.parchment,
                                )
                              : GoogleFonts.ebGaramond(
                                  fontSize: 19,
                                  height: 1.5,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.parchment,
                                ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizedText(language, '\u1218\u12dd\u1219\u122d 119:164', 'PSALM 119:164'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                            color: AppColors.gold.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
