import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_format.dart';
import '../../core/models/certificate_verification.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_chip.dart';

/// Scans a certificate QR code and resolves it through the public
/// `rpc_verify_certificate` endpoint — slice 6.
///
/// The camera is only an input method: whatever it reads goes through the same
/// [CertificateService.verify] call as a hand-typed code, so scanning is never a
/// second, weaker path. The endpoint returns only non-sensitive fields (a masked
/// operator name and the franchise dates) — nothing here reveals personal data.
///
/// A manual-entry field sits under the preview at all times, both as a fallback
/// when the camera is unavailable and as the seam the widget tests use.
class CertificateVerifyScreen extends ConsumerStatefulWidget {
  const CertificateVerifyScreen({super.key});

  @override
  ConsumerState<CertificateVerifyScreen> createState() =>
      _CertificateVerifyScreenState();
}

class _CertificateVerifyScreenState
    extends ConsumerState<CertificateVerifyScreen> {
  final TextEditingController _codeController = TextEditingController();

  CertificateVerification? _result;
  bool _verifying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify(String value) async {
    if (_verifying || value.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _verifying = true);

    final result = await ref.read(certificateServiceProvider).verify(value);

    if (!mounted) return;
    setState(() {
      _result = result;
      _verifying = false;
    });
  }

  void _reset() {
    setState(() {
      _result = null;
      _codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify a certificate'),
        actions: [
          if (result != null)
            IconButton(
              tooltip: 'Scan again',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _reset,
            ),
        ],
      ),
      body: SafeArea(
        child: result == null
            ? _buildScanner(context)
            : _VerificationResult(result: result, onScanAgain: _reset),
      ),
    );
  }

  Widget _buildScanner(BuildContext context) {
    final builder = ref.watch(qrScannerViewBuilderProvider);

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              builder(context, _verify),
              if (_verifying)
                const ColoredBox(
                  color: Colors.black54,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                const _ScanHint(),
            ],
          ),
        ),
        _ManualEntry(
          controller: _codeController,
          busy: _verifying,
          onSubmit: () => _verify(_codeController.text),
        ),
      ],
    );
  }
}

/// The framing hint drawn over the camera preview.
class _ScanHint extends StatelessWidget {
  const _ScanHint();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              'Point the camera at the certificate’s QR code.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: AppRadius.card,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Scanning happens on the municipal server. No personal data is '
              'stored on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The always-available typed-code fallback.
class _ManualEntry extends StatelessWidget {
  const _ManualEntry({
    required this.controller,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Or type the code printed under the QR',
              style: TextStyle(
                color: AppColors.inkStrong,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: controller,
              enabled: !busy,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                labelText: 'Verification code',
                hintText: 'e.g. ABCD 2345 EFGH',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton(
              onPressed: busy ? null : onSubmit,
              child: const Text('Verify code'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The resolved result of a scan or a typed code.
class _VerificationResult extends StatelessWidget {
  const _VerificationResult({required this.result, required this.onScanAgain});

  final CertificateVerification result;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: [
        _OutcomeHeader(result: result),
        const SizedBox(height: AppSpacing.md),
        if (result.verificationStatus != 'not_found') ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                children: [
                  _ResultRow(
                    label: 'Certificate holder',
                    value: result.operatorDisplayName ?? '—',
                  ),
                  const Divider(height: AppSpacing.sm),
                  _ResultRow(
                    label: 'Franchise number',
                    value: result.franchiseNumber ?? '—',
                  ),
                  const Divider(height: AppSpacing.sm),
                  _ResultRow(label: 'TODA', value: result.todaName ?? '—'),
                  const Divider(height: AppSpacing.sm),
                  _ResultRow(
                    label: 'Issued on',
                    value: formatDate(result.issuedAt),
                  ),
                  const Divider(height: AppSpacing.sm),
                  _ResultRow(
                    label: 'Valid until',
                    value: formatDate(result.expiresAt),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _PrivacyNote(),
        ] else
          const _NotFoundNote(),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onScanAgain,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan another'),
        ),
      ],
    );
  }
}

class _OutcomeHeader extends StatelessWidget {
  const _OutcomeHeader({required this.result});

  final CertificateVerification result;

  @override
  Widget build(BuildContext context) {
    final valid = result.isValid;
    final notFound = result.verificationStatus == 'not_found';
    final color = valid
        ? AppColors.success
        : (notFound ? AppColors.inkMuted : AppColors.danger);
    final icon = valid
        ? Icons.verified_outlined
        : (notFound ? Icons.help_outline : Icons.error_outline);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: color),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.statusLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          verificationStatusChip(result.verificationStatus),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.inkStrong,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 16, color: AppColors.inkMuted),
            SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'The holder’s name is shown masked. The verification code '
                'identifies a franchise only and contains no personal data.',
                style: TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundNote extends StatelessWidget {
  const _NotFoundNote();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: Text(
          'No franchise matches this code. Check the characters and try again '
          '— the code is not case-sensitive, and spaces or dashes are ignored.',
          style: TextStyle(color: AppColors.inkMuted, height: 1.4),
        ),
      ),
    );
  }
}
