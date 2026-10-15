import 'package:flutter/material.dart';

import '../models/franchise_application.dart';
import '../theme.dart';

/// A chip for a `franchise_applications.status` value.
///
/// The vocabulary and colours live in one place, so a driver sees the same
/// "Approved" green and "Rejected" red wherever an application status appears
/// (list and detail).
StatusChip applicationStatusChip(String status) {
  switch (status) {
    case ApplicationStatus.approved:
      return const StatusChip(
        label: 'Approved',
        foreground: AppColors.success,
        background: AppColors.successTint,
      );
    case ApplicationStatus.rejected:
      return const StatusChip(
        label: 'Rejected',
        foreground: AppColors.danger,
        background: AppColors.dangerTint,
      );
    default:
      return const StatusChip(
        label: 'Pending review',
        foreground: AppColors.warning,
        background: AppColors.accentTint,
      );
  }
}

/// A chip for a `franchise_documents.verification_status` value.
StatusChip documentStatusChip(String status) {
  switch (status) {
    case 'verified':
      return const StatusChip(
        label: 'Verified',
        foreground: AppColors.success,
        background: AppColors.successTint,
      );
    case 'rejected':
      return const StatusChip(
        label: 'Rejected',
        foreground: AppColors.danger,
        background: AppColors.dangerTint,
      );
    default:
      return const StatusChip(
        label: 'Pending',
        foreground: AppColors.warning,
        background: AppColors.accentTint,
      );
  }
}

/// A chip for a required document that has no row on the application.
///
/// The server always records all four requirements at submission, so this is a
/// defensive state; it is styled neutrally rather than as an error.
StatusChip missingDocumentChip() {
  return const StatusChip(
    label: 'Not on file',
    foreground: AppColors.inkMuted,
    background: AppColors.greyFill,
  );
}

/// A chip for a `FranchiseRecord.state` value:
/// `active` | `expiring` | `expired` | `archived`.
StatusChip recordStateChip(String state) {
  switch (state) {
    case 'active':
      return const StatusChip(
        label: 'Active',
        foreground: AppColors.success,
        background: AppColors.successTint,
      );
    case 'expiring':
      return const StatusChip(
        label: 'Expiring soon',
        foreground: AppColors.warning,
        background: AppColors.accentTint,
      );
    case 'expired':
      return const StatusChip(
        label: 'Expired',
        foreground: AppColors.danger,
        background: AppColors.dangerTint,
      );
    default:
      return const StatusChip(
        label: 'Archived',
        foreground: AppColors.inkMuted,
        background: AppColors.greyFill,
      );
  }
}

/// A chip for a `CertificateVerification.verificationStatus` value:
/// `valid` | `expired` | `archived` | `not_found`.
StatusChip verificationStatusChip(String status) {
  switch (status) {
    case 'valid':
      return const StatusChip(
        label: 'Valid',
        foreground: AppColors.success,
        background: AppColors.successTint,
      );
    case 'expired':
      return const StatusChip(
        label: 'Expired',
        foreground: AppColors.danger,
        background: AppColors.dangerTint,
      );
    case 'archived':
      return const StatusChip(
        label: 'Archived',
        foreground: AppColors.inkMuted,
        background: AppColors.greyFill,
      );
    default:
      return const StatusChip(
        label: 'Certificate not found',
        foreground: AppColors.danger,
        background: AppColors.dangerTint,
      );
  }
}

/// A small colour-coded pill. Built only through the helpers above so the
/// colour of a status is never chosen ad hoc at a call site.
///
/// The state is carried by a leading dot as well as the colour, so the pill
/// still reads correctly for a colour-blind driver or on a washed-out screen.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
