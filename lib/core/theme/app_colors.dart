import 'package:flutter/material.dart';

/// SCI brand palette. No magic colours anywhere else in the codebase.
class AppColors {
  const AppColors._();

  /// SCI brand primary.
  static const Color primary = Color(0xFF2747AA);
  static const Color primaryDark = Color(0xFF1B3178);
  static const Color primaryLight = Color(0xFF4C6BD4);

  /// Login hero gradient (Dribbble 8759887 interpretation).
  static const List<Color> authHeroGradient = <Color>[
    Color(0xFF3A5FD0),
    Color(0xFF2747AA),
    Color(0xFF1B3178),
  ];

  static const Color surfaceLight = Color(0xFFF6F7FB);
  static const Color surfaceDark = Color(0xFF0E1116);
  static const Color cardDark = Color(0xFF171B22);

  static const Color textPrimary = Color(0xFF10151F);
  static const Color textSecondary = Color(0xFF5C6579);
  static const Color border = Color(0x142747AA);

  // Status / severity palette (cybersecurity-shot pill badges).
  static const Color statusAssigned = Color(0xFF5C6579);
  static const Color statusInProgress = Color(0xFF2747AA);
  static const Color statusSubmitted = Color(0xFF0E7C86);
  static const Color statusUnderReview = Color(0xFF7A5AF8);
  static const Color statusCorrection = Color(0xFFE07C24);
  static const Color statusResubmitted = Color(0xFF4C6BD4);
  static const Color statusApproved = Color(0xFF1E9E5A);
  static const Color statusRejected = Color(0xFFD1344B);
  static const Color statusArchived = Color(0xFF8A93A6);

  static const Color success = Color(0xFF1E9E5A);
  static const Color warning = Color(0xFFE07C24);
  static const Color danger = Color(0xFFD1344B);
  static const Color offline = Color(0xFF8A93A6);
}
