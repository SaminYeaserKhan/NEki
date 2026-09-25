import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/neki_colors.dart';

/// A premium, high-contrast, polished feedback SnackBar designed specifically
/// for Neki's Islamic aesthetic.
///
/// Eliminates dark-on-dark unreadable text by enforcing high-contrast white
/// typography, crisp emerald & gold borders, and contextual action icons.
class NekiSnackBar {
  NekiSnackBar._();

  /// Displays a beautifully styled bookmark feedback notification.
  static void showBookmark(
    BuildContext context, {
    required bool isSaved,
    required String message,
    String? badgeText,
  }) {
    show(
      context,
      message: message,
      icon: isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_remove_rounded,
      iconColor: isSaved ? NekiColors.goldLight : const Color(0xFFE2E8F0),
      badgeText: badgeText ?? (isSaved ? 'SAVED' : 'REMOVED'),
      isGoldAccent: isSaved,
    );
  }

  /// Displays a success feedback notification (e.g. copied to clipboard).
  static void showSuccess(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle_rounded,
  }) {
    show(
      context,
      message: message,
      icon: icon,
      iconColor: NekiColors.emeraldLight,
      badgeText: 'DONE',
      isGoldAccent: false,
    );
  }

  /// Base method to show a customized, floating, high-contrast Neki feedback notification.
  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info_outline_rounded,
    Color iconColor = NekiColors.emeraldLight,
    String? badgeText,
    bool isGoldAccent = false,
    Duration duration = const Duration(milliseconds: 2000),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: duration,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0C2419),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isGoldAccent
                  ? NekiColors.goldLight.withValues(alpha: 0.5)
                  : NekiColors.emeraldLight.withValues(alpha: 0.4),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              if (isGoldAccent)
                BoxShadow(
                  color: NekiColors.goldLight.withValues(alpha: 0.12),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            children: [
              // Icon container with frosted accent background
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isGoldAccent
                      ? NekiColors.goldLight.withValues(alpha: 0.2)
                      : NekiColors.emeraldPrimary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isGoldAccent
                        ? NekiColors.goldLight.withValues(alpha: 0.45)
                        : NekiColors.emeraldLight.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),

              // Notification text in crisp, guaranteed readable white
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.1,
                    height: 1.3,
                  ),
                ),
              ),

              // Optional status badge
              if (badgeText != null && badgeText.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isGoldAccent
                        ? NekiColors.goldLight.withValues(alpha: 0.15)
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isGoldAccent
                          ? NekiColors.goldLight.withValues(alpha: 0.4)
                          : Colors.white24,
                      width: 0.9,
                    ),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: isGoldAccent ? NekiColors.goldLight : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
