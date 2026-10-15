import 'package:flutter/material.dart';

import '../app_error.dart';
import '../theme.dart';

/// The one error surface every slice shows — slice 8.
///
/// Before this, each screen rendered its own `_ErrorView`/`_ErrorBody`, so an
/// offline failure could read differently from one screen to the next. Every
/// failure now goes through [classifyAppError] and renders the same way: an
/// icon chosen for the failure kind, the classified message, the actionable
/// hint (when there is one) and a single Retry action. That is the mobile
/// half of the web console's error-surface parity — the same reason/hint pair,
/// with no `/setup-required` route to send the driver to.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = classifyAppError(error);
    final hint = failure.hint;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(failure.kind), size: 40, color: AppColors.danger),
          const SizedBox(height: AppSpacing.xs),
          Text(
            failure.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.inkStrong,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (hint != null && hint.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.inkMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  /// A recognisable icon per failure kind, so "you are offline" never looks
  /// like "the database is not migrated".
  static IconData _iconFor(AppFailureKind kind) {
    switch (kind) {
      case AppFailureKind.unreachable:
        return Icons.wifi_off_outlined;
      case AppFailureKind.schemaMissing:
        return Icons.storage_outlined;
      case AppFailureKind.unauthorised:
        return Icons.lock_outline;
      case AppFailureKind.demoBlocked:
        return Icons.visibility_outlined;
      case AppFailureKind.businessRule:
      case AppFailureKind.unknown:
        return Icons.error_outline;
    }
  }
}

/// Scrolls even when its content fits, so pull-to-refresh works on the loading,
/// empty and error states — not just on a populated list.
class CenteredScrollView extends StatelessWidget {
  const CenteredScrollView({super.key, required this.child, this.padding});

  final Widget child;

  /// Optional outer padding for children that do not carry their own (an empty
  /// state, for example). [ErrorView] already pads itself.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final inner =
        padding == null ? child : Padding(padding: padding!, child: child);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: inner),
        ),
      ),
    );
  }
}
