import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'neki_colors.dart';

/// Centralised theme definitions for Neki.
///
/// Usage in `MaterialApp`:
/// ```dart
/// MaterialApp(
///   theme: NekiTheme.light,
///   darkTheme: NekiTheme.dark,
///   themeMode: ThemeMode.system,
/// )
/// ```
class NekiTheme {
  NekiTheme._();

  // ─────────────────────────────────────────────
  //  Shared values
  // ─────────────────────────────────────────────
  static const double _cardRadius = 24;
  static const double _buttonRadius = 16;

  static final _roundedCardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_cardRadius),
  );

  // ─────────────────────────────────────────────
  //  Light Theme
  // ─────────────────────────────────────────────
  static ThemeData get light {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: NekiColors.emeraldPrimary,
      onPrimary: Colors.white,
      primaryContainer: NekiColors.emeraldLight,
      onPrimaryContainer: NekiColors.emeraldDeep,
      secondary: NekiColors.gold,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFFF3D6),
      onSecondaryContainer: const Color(0xFF5C4300),
      tertiary: NekiColors.emeraldMedium,
      onTertiary: Colors.white,
      tertiaryContainer: NekiColors.emeraldMint,
      onTertiaryContainer: NekiColors.emeraldDeep,
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surface: NekiColors.warmWhite,
      onSurface: NekiColors.textOnLight,
      onSurfaceVariant: NekiColors.textSecondaryOnLight,
      outline: const Color(0xFF73796E),
      outlineVariant: const Color(0xFFC3C8BB),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: NekiColors.silhouetteDark,
      onInverseSurface: NekiColors.emeraldPale,
      inversePrimary: NekiColors.emeraldLight,
      surfaceTint: NekiColors.emeraldPrimary,
    );

    return _buildTheme(colorScheme, Brightness.light);
  }

  // ─────────────────────────────────────────────
  //  Dark Theme
  // ─────────────────────────────────────────────
  static ThemeData get dark {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: NekiColors.emeraldLight,
      onPrimary: NekiColors.nightDeep,
      primaryContainer: NekiColors.emeraldDeep,
      onPrimaryContainer: NekiColors.emeraldPale,
      secondary: NekiColors.goldLight,
      onSecondary: const Color(0xFF3D2E00),
      secondaryContainer: const Color(0xFF574500),
      onSecondaryContainer: NekiColors.goldLight,
      tertiary: NekiColors.emeraldMint,
      onTertiary: NekiColors.nightDeep,
      tertiaryContainer: NekiColors.nightElevated,
      onTertiaryContainer: NekiColors.emeraldMint,
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: NekiColors.nightSurface,
      onSurface: NekiColors.textOnDark,
      onSurfaceVariant: NekiColors.textSecondaryOnDark,
      outline: const Color(0xFF8C9388),
      outlineVariant: const Color(0xFF43483E),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: NekiColors.emeraldPale,
      onInverseSurface: NekiColors.nightDeep,
      inversePrimary: NekiColors.emeraldPrimary,
      surfaceTint: NekiColors.emeraldLight,
    );

    return _buildTheme(colorScheme, Brightness.dark);
  }

  // ─────────────────────────────────────────────
  //  Builder
  // ─────────────────────────────────────────────
  static ThemeData _buildTheme(ColorScheme cs, Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final baseTextTheme = GoogleFonts.interTextTheme(
      isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
    );

    // Apply TextDecoration.none globally — prevents underline glitch on web
    final textTheme = baseTextTheme.apply(
      decoration: TextDecoration.none,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      textTheme: textTheme,
      scaffoldBackgroundColor: cs.surface,

      // ── Extensions ──
      extensions: <ThemeExtension<dynamic>>[
        isLight ? NekiColorExtension.light : NekiColorExtension.dark,
      ],

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        ),
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        shape: _roundedCardShape,
        elevation: 0,
        color: isLight ? Colors.white : NekiColors.nightCard,
      ),

      // ── NavigationBar (bottom tabs) ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isLight ? NekiColors.warmWhite : NekiColors.nightSurface,
        indicatorColor: cs.primaryContainer.withValues(alpha: 0.35),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? cs.primary : cs.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? cs.primary : cs.onSurfaceVariant,
            size: 24,
          );
        }),
        elevation: 0,
        height: 72,
      ),

      // ── Buttons ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // ── Inputs ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? NekiColors.emeraldPale.withValues(alpha: 0.5)
            : NekiColors.nightElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: 0.4),
        thickness: 1,
        space: 24,
      ),
    );
  }
}
