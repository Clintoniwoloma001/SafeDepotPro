import 'package:flutter/material.dart';

/// Semantic colour tokens for SafeDepot Pro.
///
/// Values are stored as raw integers rather than [Color] constants so that the
/// theme can rebuild [ColorScheme] instances without a [BuildContext].
abstract final class AppColors {
  // Brand — deep industrial blue.
  static const Color brandLight = Color(0xFF12395B);
  static const Color brandContainerLight = Color(0xFFD3E4F6);
  static const Color onBrandContainerLight = Color(0xFF001E33);

  // Status colours are shared across light and dark so that a "critical"
  // item reads identically in both modes.
  static const Color severityLow = Color(0xFF2E7D32);
  static const Color severityMedium = Color(0xFFEF6C00);
  static const Color severityHigh = Color(0xFFC62828);
  static const Color severityCritical = Color(0xFF7B1FA2);
  static const Color severityUnknown = Color(0xFF5F6368);

  // Workflow / lifecycle status.
  static const Color statusOpen = Color(0xFFC62828);
  static const Color statusInProgress = Color(0xFFEF6C00);
  static const Color statusVerification = Color(0xFF1565C0);
  static const Color statusClosed = Color(0xFF2E7D32);
  static const Color statusDraft = Color(0xFF5F6368);
  static const Color statusCancelled = Color(0xFF5F6368);

  // Authentication / verification results.
  static const Color resultPass = Color(0xFF2E7D32);
  static const Color resultFail = Color(0xFFC62828);
  static const Color resultNa = Color(0xFF5F6368);
}
