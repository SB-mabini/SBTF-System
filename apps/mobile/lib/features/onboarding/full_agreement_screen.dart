import 'package:flutter/material.dart';

import '../../core/branding.dart';
import '../../core/onboarding/onboarding_content.dart';
import '../../core/theme.dart';

/// The complete User Agreement, opened from onboarding and from Settings.
///
/// The onboarding page shows one-sentence summaries only, so this screen exists
/// to make the full wording available without scrolling past every section on
/// the main step. It is read-only: acceptance happens on the onboarding page or
/// in Settings, never here.
class FullAgreementScreen extends StatelessWidget {
  const FullAgreementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Agreement')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.lg,
              ),
              children: [
                const Text(
                  AppBranding.longName,
                  style: TextStyle(
                    color: AppColors.inkStrong,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Version ${AppBranding.agreementVersion} · effective '
                  '${AppBranding.agreementEffectiveDate}',
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (var i = 0; i < agreementSections.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  _AgreementSectionCard(
                    index: i + 1,
                    section: agreementSections[i],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: AppRadius.card,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Acceptance of this agreement is recorded with its '
                          'version and the time you accepted it. For a '
                          'signed-in account it is also stored with your '
                          'profile as an audit record.',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
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

class _AgreementSectionCard extends StatelessWidget {
  const _AgreementSectionCard({
    required this.index,
    required this.section,
  });

  final int index;
  final AgreementSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    section.icon,
                    size: 17,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '$index. ${section.title}',
                    style: const TextStyle(
                      color: AppColors.inkStrong,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.compact),
            for (final paragraph in section.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  paragraph,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
