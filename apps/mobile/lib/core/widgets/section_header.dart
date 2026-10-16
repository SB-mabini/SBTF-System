import 'package:flutter/material.dart';

import '../theme.dart';

/// A quiet section title used to group a long screen into readable blocks
/// (for example "Services" or "Track & updates").
///
/// Rendering the label in the shared component keeps the tracking and weight of
/// every section break identical across the app.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;

  /// Optional widget aligned to the trailing edge of the header row.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.xs, 4, AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
