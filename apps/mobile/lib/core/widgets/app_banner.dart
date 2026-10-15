import 'package:flutter/material.dart';

import '../theme.dart';

/// The tone of an [AppBanner]. Each tone maps to exactly one foreground,
/// background and border triple, so a call site never picks colours ad hoc.
enum AppBannerTone { info, success, warning, danger }

/// An inline, full-width message strip for form-level notices — preview mode,
/// a validation problem, a resend confirmation.
///
/// It is deliberately quiet: a tinted background, a matching hairline border, a
/// leading icon and a single wrapped line of text. This is the shared vocabulary
/// so the same kind of message looks identical on every screen.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.tone = AppBannerTone.info,
    this.icon,
  });

  final String message;
  final AppBannerTone tone;

  /// Overrides the tone's default icon when supplied.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (
      Color foreground,
      Color background,
      Color border,
      IconData defaultIcon
    ) = switch (tone) {
      AppBannerTone.success => (
          AppColors.success,
          AppColors.successTint,
          AppColors.success.withAlpha(40),
          Icons.check_circle_outline,
        ),
      AppBannerTone.warning => (
          AppColors.warning,
          AppColors.warningTint,
          AppColors.warning.withAlpha(40),
          Icons.info_outline,
        ),
      AppBannerTone.danger => (
          AppColors.danger,
          AppColors.dangerTint,
          AppColors.danger.withAlpha(40),
          Icons.error_outline,
        ),
      AppBannerTone.info => (
          AppColors.primary,
          AppColors.primaryTint,
          AppColors.primary.withAlpha(30),
          Icons.info_outline,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.banner,
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, color: foreground, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
