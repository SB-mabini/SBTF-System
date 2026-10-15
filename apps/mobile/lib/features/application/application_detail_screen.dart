import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_format.dart';
import '../../core/models/application_event.dart';
import '../../core/models/franchise_application.dart';
import '../../core/models/franchise_document.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_chip.dart';
import '../documents/application_documents_screen.dart';

/// One application's full record: status, details, documents and timeline —
/// slice 4's tracker.
///
/// [_application] is the summary the list already holds, so the header and
/// details render immediately while the documents and timeline are fetched via
/// [applicationDetailProvider]. The detail read is RLS-scoped, so a stale or
/// guessed id can only ever return the caller's own row.
class ApplicationDetailScreen extends ConsumerWidget {
  const ApplicationDetailScreen({super.key, required this.application});

  final FranchiseApplication application;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(applicationDetailProvider(application.id));

    return Scaffold(
      appBar: AppBar(title: Text(application.applicationNumber)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.refresh(applicationDetailProvider(application.id).future),
          child: detailAsync.when(
            loading: () => _DetailsBody(
              application: application,
              loading: true,
              onManageDocuments: () => _openDocuments(context),
            ),
            error: (error, _) => CenteredScrollView(
              child: ErrorView(
                error: error,
                onRetry: () =>
                    ref.invalidate(applicationDetailProvider(application.id)),
              ),
            ),
            data: (detail) => _DetailsBody(
              application: detail ?? application,
              onManageDocuments: () => _openDocuments(context),
            ),
          ),
        ),
      ),
    );
  }

  void _openDocuments(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApplicationDocumentsScreen(application: application),
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.application,
    this.loading = false,
    this.onManageDocuments,
  });

  final FranchiseApplication application;
  final bool loading;

  /// Opens the slice-5 document manager. Null only if the caller has no
  /// navigation context (never in practice).
  final VoidCallback? onManageDocuments;

  @override
  Widget build(BuildContext context) {
    final rejectionReason = application.rejectionReason;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _StatusHeader(application: application),
        if (application.isRejected &&
            rejectionReason != null &&
            rejectionReason.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _RejectionBanner(reason: rejectionReason),
        ],
        const SizedBox(height: AppSpacing.md),
        const _SectionTitle('Application details'),
        _InfoCard(
          children: [
            _InfoRow(
              label: 'Type',
              value: application.isRenewal ? 'Renewal' : 'New franchise',
            ),
            _InfoRow(label: 'TODA', value: application.todaName ?? ''),
            _InfoRow(label: 'Operator', value: application.operatorFullName),
            _InfoRow(
                label: 'Contact', value: application.operatorContactNumber),
            _InfoRow(label: 'Vehicle', value: _vehicle(application)),
            _InfoRow(label: 'Plate number', value: application.plateNumber),
            _InfoRow(
              label: 'Submitted',
              value: formatDateTime(
                application.submittedAt ?? application.createdAt,
              ),
            ),
            _InfoRow(
              label: 'Reviewed',
              value: formatDateTime(application.reviewedAt),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const Expanded(child: _SectionTitle('Documents')),
            if (onManageDocuments != null)
              TextButton(
                onPressed: onManageDocuments,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 4,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Manage'),
              ),
          ],
        ),
        if (loading)
          const _InlineLoading()
        else
          _InfoCard(children: _documentRows(application.orderedDocuments)),
        const SizedBox(height: AppSpacing.md),
        const _SectionTitle('History'),
        if (loading)
          const _InlineLoading()
        else
          _TimelineCard(events: application.orderedTimeline),
      ],
    );
  }

  static String _vehicle(FranchiseApplication application) {
    final make = application.vehicleMake.trim();
    final model = application.vehicleModel.trim();
    final description = '$make $model'.trim();
    if (description.isEmpty) return '';
    final year = application.vehicleYear;
    return year > 0 ? '$description ($year)' : description;
  }

  static List<Widget> _documentRows(List<FranchiseDocument> documents) {
    if (documents.isEmpty) {
      return const [
        _InfoRow(label: 'Documents', value: 'None on file'),
      ];
    }
    return [
      for (final document in documents)
        _DocumentRow(
          label: document.shortLabel,
          status: document.verificationStatus,
          remarks: document.remarks,
        ),
    ];
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.application});

  final FranchiseApplication application;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  application.applicationNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              applicationStatusChip(application.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Submitted '
            '${formatDateTime(application.submittedAt ?? application.createdAt)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _RejectionBanner extends StatelessWidget {
  const _RejectionBanner({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This application was rejected',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A section eyebrow. Delegates to the shared [SectionHeader] so every screen
/// uses one label treatment.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => SectionHeader(title);
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              style: const TextStyle(color: AppColors.inkStrong, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.label,
    required this.status,
    required this.remarks,
  });

  final String label;
  final String status;
  final String? remarks;

  @override
  Widget build(BuildContext context) {
    final note = remarks;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.inkStrong,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              documentStatusChip(status),
            ],
          ),
          if (status == 'rejected' &&
              note != null &&
              note.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.events});

  final List<ApplicationEvent> events;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      children: events.isEmpty
          ? const [_InfoRow(label: 'History', value: 'No entries yet')]
          : [
              for (var index = 0; index < events.length; index++)
                _TimelineRow(
                    event: events[index], isLast: index == events.length - 1),
            ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});

  final ApplicationEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final note = event.note;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Icon(
                Icons.circle,
                size: 8,
                color: AppColors.primary,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.label,
                  style: const TextStyle(
                    color: AppColors.inkStrong,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (note != null && note.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  formatDateTime(event.createdAt),
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: LinearProgressIndicator(),
      ),
    );
  }
}
