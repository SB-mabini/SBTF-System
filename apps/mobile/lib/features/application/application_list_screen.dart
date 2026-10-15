import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_format.dart';
import '../../core/models/franchise_application.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/status_chip.dart';
import 'application_detail_screen.dart';
import 'application_form_screen.dart';

/// The driver's own franchise applications, newest first — slice 4, entry point.
///
/// Backed by [myApplicationsStreamProvider], so a staff decision reaches the
/// list without a manual refresh; RLS limits the stream to the caller's own
/// rows. The list is intentionally a summary: the full record, documents and
/// timeline live behind [ApplicationDetailScreen].
///
/// Slice 5 reuses the same list as its application chooser: it passes its own
/// [title] and an [onOpenApplication] that opens the document manager instead of
/// the tracker.
class ApplicationListScreen extends ConsumerWidget {
  const ApplicationListScreen({
    super.key,
    this.title = 'My applications',
    this.onOpenApplication,
  });

  final String title;

  /// What to do when a row is tapped. Defaults to the slice-4 tracker; slice 5
  /// supplies one that opens the document manager.
  final void Function(BuildContext context, FranchiseApplication application)?
      onOpenApplication;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(myApplicationsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(myApplicationsStreamProvider.future),
          child: applicationsAsync.when(
            loading: () => const CenteredScrollView(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => CenteredScrollView(
              child: ErrorView(
                error: error,
                onRetry: () => ref.invalidate(myApplicationsStreamProvider),
              ),
            ),
            data: (applications) {
              if (applications.isEmpty) {
                return EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No applications yet',
                  message: 'When you submit a franchise application it will '
                      'appear here, with its status and history.',
                  action: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ApplicationFormScreen(
                          applicationType: ApplicationType.newFranchise,
                        ),
                      ),
                    ),
                    child: const Text('Start a new application'),
                  ),
                );
              }
              final sorted = [...applications]..sort(_byNewestFirst);
              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.sm),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: sorted.length,
                itemBuilder: (context, index) => _ApplicationCard(
                  application: sorted[index],
                  onTap: () => _open(context, sorted[index]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, FranchiseApplication application) {
    final handler = onOpenApplication;
    if (handler != null) {
      handler(context, application);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApplicationDetailScreen(application: application),
      ),
    );
  }
}

/// Newest submission first; rows without a `submitted_at` sort by `created_at`,
/// and a row with neither sinks to the bottom rather than throwing.
int _byNewestFirst(FranchiseApplication a, FranchiseApplication b) {
  final dateA =
      a.submittedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final dateB =
      b.submittedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return dateB.compareTo(dateA);
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onTap});

  final FranchiseApplication application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if ((application.todaName ?? '').isNotEmpty) application.todaName!,
      if (application.plateNumber.isNotEmpty) application.plateNumber,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      application.applicationNumber,
                      style: const TextStyle(
                        color: AppColors.inkStrong,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  applicationStatusChip(application.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${application.isRenewal ? 'Renewal' : 'New'} franchise',
                style:
                    const TextStyle(color: AppColors.inkStrong, fontSize: 13),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                'Submitted '
                '${formatDate(application.submittedAt ?? application.createdAt)}',
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
