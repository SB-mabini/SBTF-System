import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_error.dart';
import '../../core/models/form_request.dart';
import '../../core/models/franchise_application.dart';
import '../../core/models/toda.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/signature_pad.dart';

/// The vehicle/franchise request form — the first step of every application.
///
/// The driver completes the letter data (vehicle identity, CTC and contact),
/// uploads ONE combined OR/CR file, signs, and submits. Staff then approve or
/// reject it. When rejected, the same screen opens pre-filled and resubmits the
/// same row.
class RequestFormScreen extends ConsumerStatefulWidget {
  const RequestFormScreen({
    super.key,
    this.initialType,
    this.existing,
  });

  /// Pre-selected application type, when the caller already knows it.
  final String? initialType;

  /// A `requested` request (waiting view) or a `rejected` request (edit).
  final FormRequest? existing;

  @override
  ConsumerState<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends ConsumerState<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _ctc = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _engine = TextEditingController();
  final _chassis = TextEditingController();
  final _plate = TextEditingController();
  final _cr = TextEditingController();
  final _typedSignature = TextEditingController();
  final _purposeController = TextEditingController();

  final SignaturePadController _signature = SignaturePadController();

  String? _type;
  String? _todaId;
  String? _purpose;

  String? _orCrPath;
  String? _orCrName;
  String? _orCrMime;
  int? _orCrSize;

  String? _signaturePath;
  bool _hasInk = false;

  bool _uploading = false;
  bool _submitting = false;
  bool _profileApplied = false;
  String? _error;

  bool get _isEditingRejected =>
      widget.existing != null && widget.existing!.isRejected;

  bool get _isWaiting =>
      widget.existing != null && widget.existing!.isRequested;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    final existing = widget.existing;
    if (existing != null) {
      _type = existing.applicationType;
      _todaId = existing.todaId;
      _purpose = existing.purpose;
      _purposeController.text = existing.purpose ?? '';
      _ctc.text = existing.ctcNumber ?? '';
      _make.text = existing.vehicleMake ?? '';
      _model.text = existing.vehicleModel ?? '';
      _engine.text = existing.engineNumber ?? '';
      _chassis.text = existing.chassisNumber ?? '';
      _plate.text = existing.plateNumber ?? '';
      _cr.text = existing.crNumber ?? '';
      _typedSignature.text = existing.signatureTypedName ?? '';
      _orCrPath = existing.orCrStoragePath;
      _orCrName = existing.orCrFileName;
      _orCrMime = existing.orCrMimeType;
      _orCrSize = existing.orCrFileSizeBytes;
      _signaturePath = existing.signatureStoragePath;
    }
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _ctc,
      _make,
      _model,
      _engine,
      _chassis,
      _plate,
      _cr,
      _typedSignature,
      _purposeController,
    ]) {
      controller.dispose();
    }
    _signature.dispose();
    super.dispose();
  }

  void _applyProfile() {
    if (_profileApplied) return;
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) return;
    _profileApplied = true;
    if (_ctc.text.isEmpty) {
      // The profile has no CTC column; leave it blank for the driver.
    }
  }

  // -------------------------------------------------------------------------
  // OR/CR
  // -------------------------------------------------------------------------
  Future<void> _pickOrCr() async {
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) {
      setState(() => _error = 'Your profile is still loading. Please wait.');
      return;
    }

    final picked = await ref.read(documentPickerProvider).pick();
    if (!mounted || picked == null) return;

    if (!picked.isAcceptedType) {
      setState(() => _error = 'Choose a PDF, JPEG or PNG file.');
      return;
    }
    if (!picked.isWithinSizeLimit) {
      setState(() => _error = 'The OR/CR must not exceed 10 MB.');
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final path = await ref.read(formRequestServiceProvider).uploadOrCr(
            profileId: profile.id,
            bytes: picked.bytes,
            fileName: picked.fileName,
            mimeType: picked.mimeType,
          );
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _orCrPath = path;
        _orCrName = picked.fileName;
        _orCrMime = picked.mimeType;
        _orCrSize = picked.sizeBytes;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = failure.message;
      });
    }
  }

  // -------------------------------------------------------------------------
  // Submit
  // -------------------------------------------------------------------------
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;

    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) {
      setState(() => _error = 'Your profile is still loading. Please wait.');
      return;
    }

    if (_orCrPath == null) {
      setState(() => _error = 'Upload the combined OR/CR file.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // Draw the signature to PNG only when the driver used the pad.
      String? signaturePath = _signaturePath;
      String? typed;
      if (_hasInk) {
        final bytes = await _signature.exportPng();
        if (bytes != null) {
          signaturePath = await ref
              .read(formRequestServiceProvider)
              .uploadSignature(profileId: profile.id, bytes: bytes);
        }
        typed = null;
      } else {
        signaturePath = null;
        typed = _typedSignature.text.trim().isEmpty
            ? null
            : _typedSignature.text.trim();
      }

      final submission = FormRequestSubmission(
        applicationType: _type ?? ApplicationType.newFranchise,
        todaId: _todaId ?? '',
        purpose: _purpose,
        ctcNumber: _ctc.text.trim(),
        vehicleMake: _make.text.trim(),
        vehicleModel: _model.text.trim(),
        engineNumber: _engine.text.trim(),
        chassisNumber: _chassis.text.trim(),
        plateNumber: _plate.text.trim(),
        crNumber: _cr.text.trim(),
        orCrStoragePath: _orCrPath!,
        orCrFileName: _orCrName ?? 'or-cr',
        orCrMimeType: _orCrMime ?? 'application/pdf',
        orCrFileSizeBytes: _orCrSize ?? 0,
        signatureStoragePath: signaturePath,
        signatureTypedName: typed,
      );

      final service = ref.read(formRequestServiceProvider);
      final saved = _isEditingRejected
          ? await service.updateRejected(widget.existing!.id, submission)
          : await service.request(submission);

      if (!mounted) return;
      ref.invalidate(openFormRequestProvider);
      ref.invalidate(myFormRequestsProvider);
      ref.invalidate(latestRejectedFormRequestProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditingRejected
                ? 'Request resubmitted to staff.'
                : 'Request submitted. Staff will review it.',
          ),
        ),
      );
      Navigator.of(context).pop(saved);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error =
            'Could not submit the request. Check your connection and try again.';
      });
    }
  }

  Future<void> _cancelRequest() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text(
          'You will need to file a new request form before applying again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(formRequestServiceProvider).cancel(existing.id);
      if (!mounted) return;
      ref.invalidate(openFormRequestProvider);
      ref.invalidate(myFormRequestsProvider);
      Navigator.of(context).pop();
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.message);
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    _applyProfile();
    final profile = ref.watch(profileProvider).valueOrNull;
    final existing = widget.existing;

    if (_isWaiting) {
      return _WaitingScaffold(
        request: existing!,
        onCancel: _cancelRequest,
        onRefresh: () {
          ref.invalidate(openFormRequestProvider);
          ref.invalidate(myFormRequestsProvider);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditingRejected ? 'Edit request form' : 'Request form'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.sm),
            children: [
              if (existing?.isRejected == true) ...[
                _RejectionBanner(reason: existing!.rejectionReason),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (_error != null) ...[
                _ErrorBanner(message: _error!),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SectionHeader('Applicant'),
              _ReadOnlyRow(
                label: 'Name',
                value: profile?.fullName ?? '—',
              ),
              _ReadOnlyRow(
                label: 'Contact number',
                value: profile?.contactNumber ?? '—',
              ),
              const SizedBox(height: AppSpacing.xs),
              const SectionHeader('Request'),
              _typeField(),
              const SizedBox(height: AppSpacing.sm),
              _todaField(),
              const SizedBox(height: AppSpacing.sm),
              _field(
                label: 'Purpose (optional)',
                controller: _purposeController,
                hint: 'e.g. Replacement of an expired franchise',
                maxLength: 500,
                onChanged: (value) => _purpose = value,
              ),
              _field(
                label: 'CTC / Cedula number',
                controller: _ctc,
                hint: 'e.g. 1234567',
                requiredMessage: 'CTC / Cedula number is required.',
                maxLength: 40,
              ),
              const SizedBox(height: AppSpacing.xs),
              const SectionHeader('Tricycle'),
              _field(
                label: 'Certificate of Registration (CR) number',
                controller: _cr,
                hint: 'e.g. 1234567890',
                textCapitalization: TextCapitalization.characters,
                requiredMessage: 'CR number is required.',
                maxLength: 60,
              ),
              _field(
                label: 'Make',
                controller: _make,
                hint: 'Honda',
                requiredMessage: 'Vehicle make is required.',
                maxLength: 60,
              ),
              _field(
                label: 'Model',
                controller: _model,
                hint: 'TMX 155',
                requiredMessage: 'Vehicle model is required.',
                maxLength: 60,
              ),
              _field(
                label: 'Engine number',
                controller: _engine,
                hint: 'ENG-12345',
                requiredMessage: 'Engine number is required.',
                minLength: 3,
                maxLength: 40,
              ),
              _field(
                label: 'Chassis number',
                controller: _chassis,
                hint: 'CHS-12345',
                requiredMessage: 'Chassis number is required.',
                minLength: 3,
                maxLength: 40,
              ),
              _field(
                label: 'Plate number',
                controller: _plate,
                hint: 'ABC 1234',
                textCapitalization: TextCapitalization.characters,
                requiredMessage: 'Plate number is required.',
                minLength: 3,
                maxLength: 20,
              ),
              const SizedBox(height: AppSpacing.xs),
              const SectionHeader('OR / CR (one combined file)'),
              const Text(
                'Upload the front and back of the OR/CR as ONE PDF or photo. '
                'It will be reused automatically when you submit the application.',
                style: TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _OrCrTile(
                fileName: _orCrName,
                uploading: _uploading,
                onPick: _uploading ? null : _pickOrCr,
              ),
              const SizedBox(height: AppSpacing.xs),
              const SectionHeader('Signature'),
              const Text(
                'Draw your signature below, or type your full name if drawing '
                'is not possible.',
                style: TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SignaturePad(
                controller: _signature,
                onChanged: (hasInk) => setState(() {
                  _hasInk = hasInk;
                  if (hasInk) _signaturePath = null;
                }),
              ),
              if (!_hasInk)
                _field(
                  label: 'Typed signature',
                  controller: _typedSignature,
                  hint: 'Your full name',
                  textCapitalization: TextCapitalization.words,
                ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  _submitting
                      ? 'Submitting…'
                      : _isEditingRejected
                          ? 'Resubmit request'
                          : 'Submit request',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeField() {
    return FormField<String>(
      initialValue: _type,
      validator: (value) =>
          value == null ? 'Select an application type.' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TypeChoice(
            selected: field.value == ApplicationType.newFranchise,
            title: 'New franchise',
            subtitle: 'First franchise for this tricycle',
            onTap: () {
              setState(() => _type = ApplicationType.newFranchise);
              field.didChange(ApplicationType.newFranchise);
            },
          ),
          const SizedBox(height: 8),
          _TypeChoice(
            selected: field.value == ApplicationType.renewal,
            title: 'Renewal',
            subtitle: 'Renew an existing franchise',
            onTap: () {
              setState(() => _type = ApplicationType.renewal);
              field.didChange(ApplicationType.renewal);
            },
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                field.errorText!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _todaField() {
    final todasAsync = ref.watch(todaListProvider);
    return todasAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => _ErrorBanner(
        message: 'Could not load the TODA list.',
        onRetry: () => ref.invalidate(todaListProvider),
      ),
      data: (todas) => FormField<String>(
        initialValue: todas.any((toda) => toda.id == _todaId) ? _todaId : null,
        validator: (value) => value == null || value.isEmpty
            ? 'Select an accredited TODA.'
            : null,
        builder: (field) {
          Toda? selected;
          for (final toda in todas) {
            if (toda.id == field.value) {
              selected = toda;
              break;
            }
          }
          return InputDecorator(
            decoration: InputDecoration(
              labelText: 'TODA',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: const Icon(Icons.arrow_drop_down),
              errorText: field.errorText,
            ),
            isEmpty: selected == null,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selected?.id,
                hint: const Text('Select your TODA'),
                items: [
                  for (final toda in todas)
                    DropdownMenuItem<String>(
                      value: toda.id,
                      child: Text(toda.name),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _todaId = value);
                  field.didChange(value);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? requiredMessage,
    int minLength = 1,
    int? maxLength,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.inkStrong,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            onChanged: onChanged,
            decoration: InputDecoration(hintText: hint),
            validator: (value) {
              final text = (value ?? '').trim();
              if (requiredMessage != null && text.length < minLength) {
                return requiredMessage;
              }
              if (maxLength != null && text.length > maxLength) {
                return 'Must not exceed $maxLength characters.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _WaitingScaffold extends StatelessWidget {
  const _WaitingScaffold({
    required this.request,
    required this.onCancel,
    required this.onRefresh,
  });

  final FormRequest request;
  final VoidCallback onCancel;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request form'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.accentTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hourglass_top_outlined,
                        color: AppColors.warning,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Waiting for staff approval',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkStrong,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your request ${request.formNumber} is with the franchising '
                      'office. You can start the application once it is approved.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkMuted,
                        height: 1.5,
                      ),
                    ),
                    if (request.reviewDueAt != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Target review: ${_formatDate(request.reviewDueAt!)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkStrong,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close),
              label: const Text('Cancel request'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrCrTile extends StatelessWidget {
  const _OrCrTile({
    required this.fileName,
    required this.uploading,
    required this.onPick,
  });

  final String? fileName;
  final bool uploading;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryTint,
          child: Icon(
            fileName == null ? Icons.upload_file : Icons.picture_as_pdf,
            color: AppColors.primary,
          ),
        ),
        title: Text(fileName ?? 'Upload combined OR/CR'),
        subtitle: Text(
          fileName == null
              ? 'PDF, JPEG or PNG · up to 10 MB'
              : 'Tap to replace',
        ),
        trailing: uploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: onPick,
      ),
    );
  }
}

class _TypeChoice extends StatelessWidget {
  const _TypeChoice({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.input,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : AppColors.surface,
          borderRadius: AppRadius.input,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.inkMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkStrong,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.inkStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectionBanner extends StatelessWidget {
  const _RejectionBanner({required this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: AppRadius.box,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Staff returned your request',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reason ?? 'Please review the details and resubmit.',
            style: const TextStyle(color: AppColors.inkStrong, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: AppRadius.box,
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
