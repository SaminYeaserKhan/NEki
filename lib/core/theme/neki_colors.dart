import 'package:flutter/material.dart';

/// Classifies how bright the current sky gradient is.
/// Used by all adaptive color methods to pick the right text/card colors.
enum GradientTone { dark, midTone, light }

/// Core color palette for the Neki app.
///
/// Derived from the emerald-green mosque-silhouette aesthetic
/// shown in the Figma design. Two modes: Light (daytime warmth)
/// and Dark (nighttime depth).
class NekiColors {
  NekiColors._();

  // ─────────────────────────────────────────────
  //  Brand Emerald Palette
  // ─────────────────────────────────────────────
  static const Color emeraldDeep = Color(0xFF1B5E3B);
  static const Color emeraldPrimary = Color(0xFF2E7D52);
  static const Color emeraldMedium = Color(0xFF4A9B6E);
  static const Color emeraldLight = Color(0xFF6DBF8B);
  static const Color emeraldPale = Color(0xFFE8F5E9);
  static const Color emeraldMint = Color(0xFFA8D5BA);

  // ─────────────────────────────────────────────
  //  Accent Colors
  // ─────────────────────────────────────────────
  static const Color gold = Color(0xFFD4A44C);
  static const Color goldLight = Color(0xFFE8C96A);
  static const Color cream = Color(0xFFF5F2E8);
  static const Color warmWhite = Color(0xFFFAF8F0);

  // ─────────────────────────────────────────────
  //  Dark-Mode Surface Colors
  // ─────────────────────────────────────────────
  static const Color nightDeep = Color(0xFF0D1B14);
  static const Color nightSurface = Color(0xFF162A1F);
  static const Color nightElevated = Color(0xFF1E3A2C);
  static const Color nightCard = Color(0xFF243D30);

  // ─────────────────────────────────────────────
  //  Silhouette Colors
  // ─────────────────────────────────────────────
  static const Color silhouetteDark = Color(0xFF1A3D2B);
  static const Color silhouetteMid = Color(0xFF2D5E43);
  static const Color silhouetteLight = Color(0xFF3D7A57);

  // ─────────────────────────────────────────────
  //  Text Colors
  // ─────────────────────────────────────────────
  static const Color textOnDark = Color(0xFFE8F5E9);
  static const Color textSecondaryOnDark = Color(0xFFA5D6B8);
  static const Color textOnLight = Color(0xFF1A3D2B);
  static const Color textSecondaryOnLight = Color(0xFF4A6B58);

  // ─────────────────────────────────────────────
  //  Time-of-Day Sky Gradients (4 stops each)
  // ─────────────────────────────────────────────

  /// Fajr (pre-dawn): Deep indigo → soft lavender
  static const List<Color> fajrGradient = [
    Color(0xFF0F0C29),
    Color(0xFF1A1A3E),
    Color(0xFF302B63),
    Color(0xFF544A7D),
  ];

  /// Sunrise: Warm coral → golden → pale sky
  static const List<Color> sunriseGradient = [
    Color(0xFFB8D4E3),
    Color(0xFFF5DEB3),
    Color(0xFFF2C572),
    Color(0xFFE8975E),
  ];

  /// Dhuhr (midday): Clear sky blue
  static const List<Color> dhuhrGradient = [
    Color(0xFF56CCF2),
    Color(0xFF7DD5F5),
    Color(0xFFA8E0F8),
    Color(0xFFD4EEF9),
  ];

  /// Asr (afternoon): Warm amber tones
  static const List<Color> asrGradient = [
    Color(0xFF87CEAB),
    Color(0xFFB8D49E),
    Color(0xFFE2D5A3),
    Color(0xFFF0C27F),
  ];

  /// Maghrib (sunset): Purple → magenta → deep orange
  static const List<Color> maghribGradient = [
    Color(0xFF2C3E50),
    Color(0xFF8E44AD),
    Color(0xFFE74C3C),
    Color(0xFFF39C12),
  ];

  /// Isha (night): Deep navy → dark emerald — matches Figma design
  static const List<Color> ishaGradient = [
    Color(0xFF0B1520),
    Color(0xFF0D1F18),
    Color(0xFF132E20),
    Color(0xFF1A3D2B),
  ];

  /// Returns the sky gradient colours for the given hour (0–23).
  static List<Color> gradientForHour(int hour) {
    if (hour >= 4 && hour < 6) return fajrGradient;
    if (hour >= 6 && hour < 7) return sunriseGradient;
    if (hour >= 7 && hour < 15) return dhuhrGradient;
    if (hour >= 15 && hour < 17) return asrGradient;
    if (hour >= 17 && hour < 19) return maghribGradient;
    return ishaGradient; // 19:00 – 04:00
  }

  /// Whether the given hour qualifies as a "dark sky" period
  /// (used to decide if stars should be visible).
  static bool isDarkSky(int hour) {
    return hour >= 19 || hour < 6;
  }

  // ─────────────────────────────────────────────
  //  Per-gradient adaptive color system
  // ─────────────────────────────────────────────

  /// Classifies the gradient brightness for [hour] into 3 tiers.
  ///
  /// - **dark**: Isha (19–4), Fajr (4–6) — deep navy/indigo
  /// - **midTone**: Sunrise (6–7), Maghrib (17–19) — warm/purple mid-tones
  /// - **light**: Dhuhr (7–15), Asr (15–17) — bright blue/green/amber
  static GradientTone gradientTone(int hour) {
    if (hour >= 4 && hour < 6) return GradientTone.dark;      // Fajr
    if (hour >= 6 && hour < 7) return GradientTone.midTone;   // Sunrise
    if (hour >= 7 && hour < 15) return GradientTone.light;    // Dhuhr
    if (hour >= 15 && hour < 17) return GradientTone.light;   // Asr
    if (hour >= 17 && hour < 19) return GradientTone.midTone; // Maghrib
    return GradientTone.dark;                                  // Isha
  }

  /// Kept for backward compat — true when gradient is bright enough for dark text.
  static bool isLightGradient(int hour) =>
      gradientTone(hour) == GradientTone.light;

  /// Card background color adaptive to the current gradient brightness.
  static Color adaptiveCardColor(int hour) {
    switch (gradientTone(hour)) {
      case GradientTone.dark:
        return Colors.white.withValues(alpha: 0.08);          // Glass
      case GradientTone.midTone:
        return const Color(0xCC1A3D2B);                       // Semi-dark green
      case GradientTone.light:
        return const Color(0xE6FFFFFF);                        // Opaque white
    }
  }

  /// Primary text color — always high contrast against the card.
  static Color adaptiveTextPrimary(int hour) {
    switch (gradientTone(hour)) {
      case GradientTone.dark:
        return Colors.white;
      case GradientTone.midTone:
        return const Color(0xFFF5F2E8);                        // Cream on dark card
      case GradientTone.light:
        return const Color(0xFF1A3D2B);                        // Dark green on white card
    }
  }

  /// Secondary text color — softer version of primary.
  static Color adaptiveTextSecondary(int hour) {
    switch (gradientTone(hour)) {
      case GradientTone.dark:
        return Colors.white.withValues(alpha: 0.6);
      case GradientTone.midTone:
        return const Color(0xAAF5F2E8);
      case GradientTone.light:
        return const Color(0xFF4A6B58);                        // Muted green
    }
  }

  /// Section header text color.
  static Color adaptiveSectionHeader(int hour) {
    switch (gradientTone(hour)) {
      case GradientTone.dark:
        return Colors.white;
      case GradientTone.midTone:
        return const Color(0xFFF5F2E8);
      case GradientTone.light:
        return const Color(0xFF1A3D2B);
    }
  }

  /// Card border color.
  static Color adaptiveCardBorder(int hour) {
    switch (gradientTone(hour)) {
      case GradientTone.dark:
        return Colors.white.withValues(alpha: 0.06);
      case GradientTone.midTone:
        return Colors.white.withValues(alpha: 0.12);
      case GradientTone.light:
        return const Color(0x1A1A3D2B);                        // Subtle dark green
    }
  }

  /// Icon/accent color that contrasts with the card background.
  static Color adaptiveIconColor(int hour) {
    switch (gradientTone(hour)) {
      case GradientTone.dark:
        return Colors.white.withValues(alpha: 0.9);
      case GradientTone.midTone:
        return const Color(0xFFF5F2E8);
      case GradientTone.light:
        return const Color(0xFF2E7D52);                        // Emerald
    }
  }

  /// Linearly interpolates two equal-length colour lists.
  static List<Color> lerpGradient(
    List<Color> a,
    List<Color> b,
    double t,
  ) {
    assert(a.length == b.length);
    return List.generate(
      a.length,
      (i) => Color.lerp(a[i], b[i], t)!,
    );
  }
}

// ─────────────────────────────────────────────────
//  ThemeExtension for custom Neki-specific colours
// ─────────────────────────────────────────────────

/// Custom colours not covered by Material's [ColorScheme].
///
/// Access via `Theme.of(context).extension<NekiColorExtension>()`.
class NekiColorExtension extends ThemeExtension<NekiColorExtension> {
  final Color mosqueSilhouetteFront;
  final Color mosqueSilhouetteBack;
  final Color crescentGold;
  final Color cardGlass;
  final Color cardGlassBorder;

  const NekiColorExtension({
    required this.mosqueSilhouetteFront,
    required this.mosqueSilhouetteBack,
    required this.crescentGold,
    required this.cardGlass,
    required this.cardGlassBorder,
  });

  static const light = NekiColorExtension(
    mosqueSilhouetteFront: NekiColors.silhouetteDark,
    mosqueSilhouetteBack: NekiColors.silhouetteMid,
    crescentGold: NekiColors.gold,
    cardGlass: Color(0x40FFFFFF),
    cardGlassBorder: Color(0x30FFFFFF),
  );

  static const dark = NekiColorExtension(
    mosqueSilhouetteFront: Color(0xFF0A1F15),
    mosqueSilhouetteBack: Color(0xFF132A1F),
    crescentGold: NekiColors.goldLight,
    cardGlass: Color(0x20FFFFFF),
    cardGlassBorder: Color(0x15FFFFFF),
  );

  @override
  NekiColorExtension copyWith({
    Color? mosqueSilhouetteFront,
    Color? mosqueSilhouetteBack,
    Color? crescentGold,
    Color? cardGlass,
    Color? cardGlassBorder,
  }) {
    return NekiColorExtension(
      mosqueSilhouetteFront:
          mosqueSilhouetteFront ?? this.mosqueSilhouetteFront,
      mosqueSilhouetteBack:
          mosqueSilhouetteBack ?? this.mosqueSilhouetteBack,
      crescentGold: crescentGold ?? this.crescentGold,
      cardGlass: cardGlass ?? this.cardGlass,
      cardGlassBorder: cardGlassBorder ?? this.cardGlassBorder,
    );
  }

  @override
  NekiColorExtension lerp(NekiColorExtension? other, double t) {
    if (other is! NekiColorExtension) return this;
    return NekiColorExtension(
      mosqueSilhouetteFront:
          Color.lerp(mosqueSilhouetteFront, other.mosqueSilhouetteFront, t)!,
      mosqueSilhouetteBack:
          Color.lerp(mosqueSilhouetteBack, other.mosqueSilhouetteBack, t)!,
      crescentGold: Color.lerp(crescentGold, other.crescentGold, t)!,
      cardGlass: Color.lerp(cardGlass, other.cardGlass, t)!,
      cardGlassBorder:
          Color.lerp(cardGlassBorder, other.cardGlassBorder, t)!,
    );
  }
}
