import 'package:flutter/material.dart';

class AppColors {
  static const Color backgroundDark = Color(0xFF0A0E1A);
  static const Color backgroundCard = Color(0xFF151A2E);
  static const Color backgroundSurface = Color(0xFF1E2538);
  static const Color backgroundOverlay = Color(0x80000000);

  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFE5C563);
  static const Color goldDark = Color(0xFFAA8C2C);
  static const Color bronze = Color(0xFFCD7F32);
  static const Color goldGlow = Color(0x40D4AF37);
  static const Color glow = Color(0x40D4AF37);

  static const Color green = Color(0xFF38714F);
  static const Color red = Color(0xFFB23B3B);
  static const Color grey = Color(0xFF6B7280);
  static const Color white = Color(0xFFF8F9FA);
  static const Color whiteMuted = Color(0xFF9CA3AF);

  static const Color success = Color(0xFF38714F);
  static const Color error = Color(0xFFB23B3B);
  static const Color warning = Color(0xFFFFA500);
  static const Color info = Color(0xFF4A90E2);
  static const Color pending = Color(0xFF6B7280);

  static const Color textPrimary = Color(0xFFF8F9FA);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFF6B7280);
  static const Color textInverse = Color(0xFF0A0E1A);

  static const Color border = Color(0xFF2D3748);
  static const Color borderLight = Color(0xFF374151);
  static const Color divider = Color(0xFF1A202C);
  static const Color dividerLight = Color(0xFF2A3447);

  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  static const Color white10 = Color(0x1AFFFFFF);
  static const Color white20 = Color(0x33FFFFFF);
  static const Color white30 = Color(0x4DFFFFFF);
  static const Color white50 = Color(0x80FFFFFF);
  static const Color white70 = Color(0xB3FFFFFF);

  static const Color black10 = Color(0x1A000000);
  static const Color black20 = Color(0x33000000);
  static const Color black30 = Color(0x4D000000);
  static const Color black50 = Color(0x80000000);
  static const Color black70 = Color(0xB3000000);

  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x33000000);
  static const Color shadowHeavy = Color(0x66000000);

  static const List<Color> goldGradient = [
    goldLight,
    gold,
    goldDark,
  ];

  static const List<Color> bronzeGradient = [
    Color(0xFFE5A85E),
    bronze,
    Color(0xFF9E6326),
  ];

  static Color get buttonPressed => goldDark;
  static Color get buttonDisabled => gold.withOpacity(0.3);
  static Color get inputFocused => gold;
  static Color get inputError => error;
  static Color get selectionColor => gold.withOpacity(0.2);
  static Color get rippleColor => gold.withOpacity(0.1);

  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity.clamp(0.0, 1.0));
  }

  static LinearGradient createGoldGradient({
    Alignment begin = Alignment.topCenter,
    Alignment end = Alignment.bottomCenter,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: goldGradient,
    );
  }

  static List<BoxShadow> createGoldGlow({
    double blurRadius = 20,
    double spreadRadius = 2,
    Offset offset = const Offset(0, 4),
  }) {
    return [
      BoxShadow(
        color: goldGlow,
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
        offset: offset,
      ),
    ];
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'signed':
      case 'accepted':
      case 'completed':
        return success;
      case 'rejected':
      case 'cancelled':
      case 'failed':
        return error;
      case 'draft':
      case 'pending':
      case 'waiting':
        return warning;
      case 'shared':
      case 'sent':
      case 'in_progress':
        return info;
      case 'expired':
      case 'archived':
        return pending;
      default:
        return grey500;
    }
  }

  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'signed':
      case 'accepted':
      case 'completed':
        return Icons.check_circle;
      case 'rejected':
      case 'cancelled':
        return Icons.cancel;
      case 'draft':
        return Icons.edit;
      case 'shared':
      case 'sent':
        return Icons.share;
      case 'pending':
      case 'waiting':
        return Icons.access_time;
      case 'expired':
        return Icons.archive;
      default:
        return Icons.info;
    }
  }
}