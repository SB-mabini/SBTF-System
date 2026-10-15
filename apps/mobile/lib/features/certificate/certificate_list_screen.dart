import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_format.dart';
import '../../core/models/franchise_record.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/status_chip.dart';
import 'certificate_detail_screen.dart';
import 'certificate_verify_screen.dart';

/// The driver's issued franchise certificates, newest first — slice 6.
///
/// Backed by [myRecordsStreamProvider], so a certificate issued (or archived)
/// by the municipal staff reaches this list without a manual refresh; RLS
/// limits the stream to the caller's own rows. A row opens the certificate's
/// detail, QR code and download.
class CertificateListScreen extends ConsumerWidget {
  const CertificateListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(myRecordsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificate & QR'),
        actions: [
          IconButton(
            tooltip: 'Verify a certificate',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _openVerify(context),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(myRecordsStreamProvider.future),
          child: recordsAsync.when(
            loading: () => const CenteredScrollView(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => CenteredScrollView(
              child: ErrorView(
                error: error,
                onRetry: () => ref.invalidate(myRecordsStreamProvider),
              ),
            ),
            data: (records) {
              if (records.isEmpty) {
                return EmptyState(
                  icon: Icons.verified_outlined,
                  title: 'No franchise certificate yet',
                  message:
                      'Once the municipal office approves your application, '
                      'your franchise certificate and its QR code will appear '
                      'here.',
                  action: OutlinedButton.icon(
                    onPressed: () => _openVerify(context),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Verify a certificate'),
                  ),
                );
              }
              final sorted = [...records]
                ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.sm),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: sorted.length,
                itemBuilder: (context, index) => _RecordCard(
                  record: sorted[index],
                  onTap: () => _openDetail(context, sorted[index]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, FranchiseRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CertificateDetailScreen(record: record),
      ),
    );
  }

  void _openVerify(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CertificateVerifyScreen(),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onTap});

  final FranchiseRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                      record.franchiseNumber.isEmpty
                          ? 'Franchise'
                          : record.franchiseNumber,
                      style: const TextStyle(
                        color: AppColors.inkStrong,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  recordStateChip(record.state),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _IconLine(
                icon: Icons.groups_outlined,
                text: record.todaName ?? 'TODA not recorded',
              ),
              if (record.plateNumber != null &&
                  record.plateNumber!.isNotEmpty) ...[
                const SizedBox(height: 2),
                _IconLine(
                  icon: Icons.directions_car_outlined,
                  text: record.plateNumber!,
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Issued ${formatDate(record.issuedAt)} · '
                'Expires ${formatDate(record.expiresAt)}',
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
              if (!record.hasCertificate) ...[
                const SizedBox(height: 4),
                const Text(
                  'The certificate file is not available yet.',
                  style: TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.inkMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
