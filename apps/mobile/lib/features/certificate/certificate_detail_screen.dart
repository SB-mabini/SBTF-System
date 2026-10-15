import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_error.dart';
import '../../core/date_format.dart';
import '../../core/models/franchise_record.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/verification.dart';
import '../../core/widgets/status_chip.dart';

/// One franchise certificate: its QR code, its details and its download —
/// slice 6.
///
/// The QR carries the same payload the web console prints on the certificate:
/// the public verification URL when `certificate_verification_base_url` is set,
/// otherwise the bare opaque code. No personal data is encoded. The PDF itself
/// is private and is opened through a short-lived signed URL.
class CertificateDetailScreen extends ConsumerWidget {
  const CertificateDetailScreen({super.key, required this.record});

  final FranchiseRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseUrlAsync = ref.watch(verificationBaseUrlProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Franchise certificate')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            _Header(record: record),
            const SizedBox(height: AppSpacing.md),
            const _SectionTitle('Verification QR'),
            baseUrlAsync.when(
              loading: () => const _QrLoading(),
              error: (_, __) => _QrCard(record: record, baseUrl: null),
              data: (baseUrl) => _QrCard(record: record, baseUrl: baseUrl),
            ),
            const SizedBox(height: AppSpacing.md),
            const _SectionTitle('Details'),
            _InfoCard(record: record),
            const SizedBox(height: AppSpacing.md),
            const _SectionTitle('Certificate file'),
            _CertificateActions(
                record: record, baseUrl: baseUrlAsync.valueOrNull),
          ],
        ),
      ),
    );
  }
}

/// The QR card.
///
/// [baseUrl] is null while it is still loading or when the setting is absent;
/// in both cases the payload falls back to the bare code, which verifies the
/// same way, so the QR is never blank.
class _QrCard extends StatelessWidget {
  const _QrCard({required this.record, required this.baseUrl});

  final FranchiseRecord record;
  final String? baseUrl;

  @override
  Widget build(BuildContext context) {
    final payload = certificateQrPayload(
      baseUrl: baseUrl,
      verificationCode: record.verificationCode,
    );
    final hasBaseUrl = (baseUrl ?? '').trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.box,
                border: Border.all(color: AppColors.border),
              ),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.primary,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              record.verificationCode,
              style: const TextStyle(
                color: AppColors.inkStrong,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasBaseUrl
                  ? 'Scan to open the public verification page. The code '
                      'identifies this franchise only — it contains no personal '
                      'information.'
                  : 'Type this code at the municipal verification page. The code '
                      'identifies this franchise only — it contains no personal '
                      'information.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.inkMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrLoading extends StatelessWidget {
  const _QrLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.record});

  final FranchiseRecord record;

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
                  record.franchiseNumber.isEmpty
                      ? 'Franchise'
                      : record.franchiseNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              recordStateChip(record.state),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            record.state == 'active'
                ? 'Valid until ${formatDate(record.expiresAt)}.'
                : _stateSentence(record),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  String _stateSentence(FranchiseRecord record) {
    switch (record.state) {
      case 'expiring':
        final days = record.daysRemaining;
        return 'Expires in $days ${days == 1 ? 'day' : 'days'} '
            '(${formatDate(record.expiresAt)}). Renew before then.';
      case 'expired':
        return 'Expired on ${formatDate(record.expiresAt)}.';
      default:
        return 'This franchise has been archived'
            '${record.archiveReason == null ? '.' : ': ${record.archiveReason}'}';
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.record});

  final FranchiseRecord record;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Operator', record.operatorName ?? '—'),
      ('TODA', record.todaName ?? '—'),
      ('Plate number', record.plateNumber ?? '—'),
      (
        'Vehicle',
        record.vehicleDescription.isEmpty ? '—' : record.vehicleDescription,
      ),
      ('Issued on', formatDate(record.issuedAt)),
      ('Valid until', formatDate(record.expiresAt)),
      ('Verification code', record.verificationCode),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) const Divider(height: AppSpacing.sm),
              _InfoRow(label: rows[index].$1, value: rows[index].$2),
            ],
          ],
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
    return Row(
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
            value,
            style: const TextStyle(
              color: AppColors.inkStrong,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.inkStrong,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// Opens the certificate PDF, or copies its verification link.
class _CertificateActions extends ConsumerStatefulWidget {
  const _CertificateActions({required this.record, required this.baseUrl});

  final FranchiseRecord record;
  final String? baseUrl;

  @override
  ConsumerState<_CertificateActions> createState() =>
      _CertificateActionsState();
}

class _CertificateActionsState extends ConsumerState<_CertificateActions> {
  bool _opening = false;

  FranchiseRecord get _record => widget.record;

  @override
  Widget build(BuildContext context) {
    final hasCertificate = _record.hasCertificate;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hasCertificate)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  'The certificate file is not available yet. It appears here '
                  'once the municipal office attaches it.',
                  style: TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            FilledButton.icon(
              onPressed: hasCertificate && !_opening ? _open : null,
              icon: _opening
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Open certificate'),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: _copyLink,
              icon: const Icon(Icons.link),
              label: const Text('Copy verification link'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open() async {
    setState(() => _opening = true);
    final service = ref.read(certificateServiceProvider);
    final launcher = ref.read(urlLauncherProvider);

    String? url;
    try {
      url = await service.certificateSignedUrl(_record);
    } on AppFailure catch (failure) {
      if (mounted) _showMessage(failure.message, isError: true);
    }
    if (!mounted) return;

    if (url == null || url.isEmpty) {
      setState(() => _opening = false);
      _showMessage(
        'Could not prepare the certificate for download. Please try again.',
        isError: true,
      );
      return;
    }

    bool launched = false;
    try {
      launched = await launcher(Uri.parse(url));
    } catch (_) {
      launched = false;
    }
    if (!mounted) return;

    setState(() => _opening = false);
    if (!launched) {
      _showMessage(
        'No app is available to open the certificate. The link has been '
        'copied instead.',
        isError: true,
      );
      await _copyLink();
    }
  }

  Future<void> _copyLink() async {
    final payload = certificateQrPayload(
      baseUrl: widget.baseUrl,
      verificationCode: _record.verificationCode,
    );
    await Clipboard.setData(ClipboardData(text: payload));
    if (mounted) {
      _showMessage('Verification link copied.');
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : null,
      ),
    );
  }
}
