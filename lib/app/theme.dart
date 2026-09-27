import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rise_for_prayer/utils/colors.dart';

ThemeData buildTheme({required Brightness brightness}) {
  final palette = brightness == Brightness.light
      ? const _ThemePalette(
          background: Color(0xFFF7F3EA),
          surface: Color(0xFFFFFEFB),
          accent: AppColors.burgundy,
          // A deeper antique gold keeps labels and icons readable on cream.
          accentSoft: Color(0xFF80620C),
          divider: Color(0xFFE6DDCE),
          text: AppColors.obsidian,
        )
      : const _ThemePalette(
          background: AppColors.obsidian,
          surface: AppColors.obsidianMid,
          accent: AppColors.gold,
          accentSoft: AppColors.gold,
          divider: AppColors.parchment,
          text: AppColors.parchment,
        );

  final colorScheme = ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: brightness,
    surface: palette.surface,
    secondary: palette.accentSoft,
  ).copyWith(
    primary: palette.accent,
    secondary: palette.accentSoft,
    surface: palette.surface,
    onPrimary: brightness == Brightness.light
        ? Colors.white
        : AppColors.obsidianDark,
    onSecondary: brightness == Brightness.light
        ? AppColors.obsidianDark
        : Colors.white,
    onSurface: palette.text,
    outline: palette.divider,
    outlineVariant: palette.divider.withValues(alpha: 0.72),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    primaryColor: palette.accent,
    scaffoldBackgroundColor: palette.background,
    colorScheme: colorScheme,
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(brightness == Brightness.light ? 18 : 12),
        side: BorderSide(color: palette.divider.withValues(alpha: 0.65)),
      ),
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.cinzel(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: palette.text,
      ),
      displayMedium: GoogleFonts.cinzel(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: palette.text,
      ),
      displaySmall: GoogleFonts.cinzel(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: palette.text,
      ),
      bodyLarge: GoogleFonts.ebGaramond(
        fontSize: 16,
        color: palette.text.withValues(alpha: 0.92),
      ),
      bodyMedium: GoogleFonts.ebGaramond(
        fontSize: 14,
        color: palette.text.withValues(alpha: 0.84),
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        color: palette.text.withValues(alpha: 0.72),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: brightness == Brightness.light
            ? Colors.white
            : AppColors.obsidianDark,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: palette.accent, size: 22),
      titleTextStyle: GoogleFonts.cinzel(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: palette.text,
      ),
    ),
    iconTheme: IconThemeData(color: palette.accent, size: 20),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: palette.accent,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ).copyWith(
        overlayColor: WidgetStatePropertyAll(
          palette.accent.withValues(alpha: brightness == Brightness.light ? 0.08 : 0.14),
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: palette.divider.withValues(alpha: 0.32),
      thickness: 1,
      space: 1,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: palette.surface,
      selectedItemColor: palette.accent,
      unselectedItemColor: palette.text.withValues(alpha: 0.52),
      selectedIconTheme: const IconThemeData(size: 22),
      unselectedIconTheme: const IconThemeData(size: 20),
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
      type: BottomNavigationBarType.fixed,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.accent,
        side: BorderSide(color: palette.divider.withValues(alpha: 0.72)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.accent, width: 1.5),
      ),
    ),
  );
}

class _ThemePalette {
  const _ThemePalette({
    required this.background,
    required this.surface,
    required this.accent,
    required this.accentSoft,
    required this.divider,
    required this.text,
  });

  final Color background;
  final Color surface;
  final Color accent;
  final Color accentSoft;
  final Color divider;
  final Color text;
}
