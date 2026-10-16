import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_error.dart';
import '../../core/constants.dart';
import '../../core/models/franchise_application.dart';
import '../../core/models/toda.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/section_header.dart';

/// The new / renewal franchise application wizard — slice 3.
///
/// Five steps: application type and location, operator details, vehicle
/// details, the four documentary requirements, then review. Every field rule
/// mirrors the server's own validation in `rpc_driver_submit_application`, so
/// the RPC's sentence is only needed for races (a duplicate pending
/// application, a TODA deactivated while the form was open).
///
/// Documents are uploaded to the caller's own storage folder *before*
/// submission, exactly as the RPC requires: it re-checks the `{profile_id}/`
/// prefix and attaches the rows. Submission goes through
/// [ApplicationService.submit], which runs the same pre-validation again and
/// classifies any refusal into an [AppFailure].
class ApplicationFormScreen extends ConsumerStatefulWidget {
  const ApplicationFormScreen({super.key, required this.applicationType});

  /// [ApplicationType.newFranchise] or [ApplicationType.renewal]. The wizard
  /// opens on this step but the driver may still switch type.
  final String applicationType;

  @override
  ConsumerState<ApplicationFormScreen> createState() =>
      _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends ConsumerState<ApplicationFormScreen> {
  static const List<String> _stepTitles = <String>[
    'Type & location',
    'Operator details',
    'Vehicle details',
    'Documents',
    'Review & submit',
  ];

  final _formKey = GlobalKey<FormState>();

  // Operator
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();

  // Vehicle
  final _vehicleMake = TextEditingController();
  final _vehicleModel = TextEditingController();
  final _vehicleYear = TextEditingController();
  final _vehicleColor = TextEditingController();
  final _plate = TextEditingController();
  final _engine = TextEditingController();
  final _chassis = TextEditingController();
  final _seating = TextEditingController(text: '5');
  final _mtop = TextEditingController();
  final _body = TextEditingController();
  final _remarks = TextEditingController();

  // Letter-only fields: shown in the formal letter preview, not submitted
  // separately (the data is captured via the uploaded OR/CR and Cedula docs).
  final _crNumber = TextEditingController();
  final _ctc = TextEditingController();

  late String _type;
  String? _todaId;
  String? _barangayCode;
  String? _recordId;

  int _step = 0;
  bool _submitting = false;
  String? _submitError;

  final Map<String, ApplicationDocumentUpload> _uploads =
      <String, ApplicationDocumentUpload>{};
  final Set<String> _uploading = <String>{};
  final Map<String, String> _uploadErrors = <String, String>{};

  @override
  void initState() {
    super.initState();
    _type = widget.applicationType;

    // Prefill the operator from the signed-in profile where it is known; the
    // driver completes the address, which the profile does not carry.
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile != null) {
      _firstName.text = profile.firstName;
      _middleName.text = profile.middleName ?? '';
      _lastName.text = profile.lastName;
      _contact.text = profile.contactNumber ?? '';
      _email.text = profile.email;
    }
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _firstName,
      _middleName,
      _lastName,
      _contact,
      _address,
      _email,
      _vehicleMake,
      _vehicleModel,
      _vehicleYear,
      _vehicleColor,
      _plate,
      _engine,
      _chassis,
      _seating,
      _mtop,
      _body,
      _remarks,
      _crNumber,
      _ctc,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isRenewal => _type == ApplicationType.renewal;

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step == 3) {
      final problems = _documentProblems();
      if (problems.isNotEmpty) {
        setState(() => _submitError = problems.first);
        return;
      }
    } else if (_formKey.currentState?.validate() == false) {
      return;
    }
    setState(() {
      _submitError = null;
      _step++;
    });
  }

  void _back() {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitError = null;
      if (_step > 0) _step--;
    });
  }

  // -------------------------------------------------------------------------
  // Documents
  // -------------------------------------------------------------------------

  List<String> _documentProblems() {
    return <String>[
      for (final type in requiredDocumentTypes)
        if (!_uploads.containsKey(type))
          'Upload the ${documentLabels[type] ?? type}.',
    ];
  }

  Future<void> _pickDocument(String documentType) async {
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) {
      setState(() => _uploadErrors[documentType] =
          'Your profile is still loading. Please wait and try again.');
      return;
    }

    final picked = await ref.read(documentPickerProvider).pick();
    if (!mounted) return;
    if (picked == null) return; // cancelled

    if (!picked.isAcceptedType) {
      setState(() =>
          _uploadErrors[documentType] = 'Choose a PDF, JPEG or PNG file.');
      return;
    }
    if (!picked.isWithinSizeLimit) {
      setState(() =>
          _uploadErrors[documentType] = 'Each document must not exceed 10 MB.');
      return;
    }

    setState(() {
      _uploading.add(documentType);
      _uploadErrors.remove(documentType);
    });

    try {
      final path = await ref.read(documentServiceProvider).uploadDocument(
            profileId: profile.id,
            documentType: documentType,
            bytes: picked.bytes,
            fileName: picked.fileName,
            mimeType: picked.mimeType,
          );
      if (!mounted) return;
      setState(() {
        _uploading.remove(documentType);
        _uploadErrors.remove(documentType);
        _submitError = null;
        _uploads[documentType] = ApplicationDocumentUpload(
          documentType: documentType,
          storagePath: path,
          fileName: picked.fileName,
          fileSizeBytes: picked.sizeBytes,
          mimeType: picked.mimeType,
        );
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _uploading.remove(documentType);
        _uploadErrors[documentType] = failure.message;
      });
    }
  }

  // -------------------------------------------------------------------------
  // Submission
  // -------------------------------------------------------------------------

  ApplicationSubmission _buildSubmission() {
    return ApplicationSubmission(
      applicationType: _type,
      todaId: _todaId ?? '',
      operatorFirstName: _firstName.text.trim(),
      operatorMiddleName: _emptyToNull(_middleName.text),
      operatorLastName: _lastName.text.trim(),
      operatorContactNumber: _contact.text.trim(),
      operatorAddressLine: _address.text.trim(),
      operatorBarangayCode: _barangayCode,
      operatorEmail: _emptyToNull(_email.text),
      vehicleMake: _vehicleMake.text.trim(),
      vehicleModel: _vehicleModel.text.trim(),
      vehicleYear: int.tryParse(_vehicleYear.text.trim()) ?? 0,
      vehicleColor: _vehicleColor.text.trim(),
      plateNumber: _plate.text.trim(),
      engineNumber: _engine.text.trim(),
      chassisNumber: _chassis.text.trim(),
      seatingCapacity: int.tryParse(_seating.text.trim()) ?? 5,
      mtopNumber: _emptyToNull(_mtop.text),
      bodyNumber: _emptyToNull(_body.text),
      renewalOfRecordId: _isRenewal ? _recordId : null,
      remarks: _emptyToNull(_remarks.text),
      documents: <ApplicationDocumentUpload>[
        for (final type in requiredDocumentTypes)
          if (_uploads.containsKey(type)) _uploads[type]!,
      ],
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final submission = _buildSubmission();

    // The same rules the server applies, run before any network call.
    final problems = submission.validate();
    if (problems.isNotEmpty) {
      setState(() => _submitError = problems.first);
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final application =
          await ref.read(applicationServiceProvider).submit(submission);
      if (!mounted) return;
      ref.invalidate(myApplicationsProvider);
      ref.invalidate(activeApplicationProvider);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => _ApplicationSubmittedScreen(application: application),
        ),
      );
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError =
            'Could not submit the application. Check your connection and try again.';
      });
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRenewal ? 'Renewal application' : 'New application'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StepHeader(step: _step, titles: _stepTitles),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_submitError != null) ...[
                        _ErrorBanner(message: _submitError!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      _buildStep(),
                    ],
                  ),
                ),
              ),
            ),
            _NavigationBar(
              isFirst: _step == 0,
              isLast: _step == _stepTitles.length - 1,
              submitting: _submitting,
              onBack: _back,
              onNext: _next,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _stepTypeLocation();
      case 1:
        return _stepOperator();
      case 2:
        return _stepVehicle();
      case 3:
        return _stepDocuments();
      default:
        return _stepReview();
    }
  }

  Widget _stepTypeLocation() {
    final todasAsync = ref.watch(todaListProvider);
    final barangaysAsync = ref.watch(barangayListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Application type'),
        _TypeOption(
          selected: !_isRenewal,
          icon: Icons.note_add_outlined,
          title: 'New franchise',
          subtitle: 'First franchise for this tricycle',
          onTap: () => setState(() {
            _type = ApplicationType.newFranchise;
            _recordId = null;
          }),
        ),
        const SizedBox(height: AppSpacing.xs),
        _TypeOption(
          selected: _isRenewal,
          icon: Icons.autorenew_outlined,
          title: 'Renewal',
          subtitle: 'Renew an existing franchise',
          onTap: () => setState(() => _type = ApplicationType.renewal),
        ),
        const SizedBox(height: AppSpacing.md),
        const _SectionTitle('TODA & barangay'),
        todasAsync.when(
          loading: () => const _AsyncPad(child: LinearProgressIndicator()),
          error: (error, _) => _AsyncError(
            label: 'Could not load the TODA list.',
            onRetry: () => ref.invalidate(todaListProvider),
          ),
          data: (todas) => _todaPicker(todas),
        ),
        const SizedBox(height: AppSpacing.sm),
        barangaysAsync.when(
          loading: () => const _AsyncPad(child: LinearProgressIndicator()),
          error: (error, _) => _AsyncError(
            label: 'Could not load the barangay list.',
            onRetry: () => ref.invalidate(barangayListProvider),
          ),
          data: (barangays) => _barangayPicker(barangays),
        ),
        if (_isRenewal) ...[
          const SizedBox(height: AppSpacing.sm),
          _renewalRecordField(),
        ],
      ],
    );
  }

  Widget _todaPicker(List<Toda> todas) {
    final initialId =
        todas.any((toda) => toda.id == _todaId) ? _todaId : null;

    return FormField<String>(
      initialValue: initialId,
      validator: (value) =>
          value == null ? 'Select an accredited TODA.' : null,
      builder: (field) {
        Toda? selected;
        for (final toda in todas) {
          if (toda.id == field.value) {
            selected = toda;
            break;
          }
        }

        return InkWell(
          borderRadius: AppRadius.input,
          onTap: todas.isEmpty
              ? null
              : () async {
                  final selectedId = await _showTodaPicker(todas);
                  if (selectedId != null && mounted) {
                    setState(() => _todaId = selectedId);
                    field.didChange(selectedId);
                  }
                },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'TODA',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: const Icon(Icons.arrow_drop_down),
              errorText: field.errorText,
            ),
            isEmpty: selected == null,
            child: Text(
              selected?.name ?? 'Select your TODA',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected == null
                        ? AppColors.inkMuted
                        : AppColors.inkStrong,
                  ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showTodaPicker(List<Toda> todas) {
    final sortedTodas = [...todas]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose your TODA',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  itemCount: sortedTodas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final toda = sortedTodas[index];
                    final isSelected = toda.id == _todaId;
                    return ListTile(
                      dense: true,
                      minVerticalPadding: 8,
                      title: Text(
                        toda.name,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.inkStrong,
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check,
                              color: AppColors.primary,
                              size: 18,
                            )
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(toda.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barangayPicker(List<Barangay> barangays) {
    Barangay? selected;
    for (final barangay in barangays) {
      if (barangay.code == _barangayCode) {
        selected = barangay;
        break;
      }
    }

    return InkWell(
      borderRadius: AppRadius.input,
      onTap: barangays.isEmpty ? null : () => _showBarangayPicker(barangays),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Barangay',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        isEmpty: selected == null,
        child: Text(
          selected?.name ?? 'Select your barangay',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color:
                    selected == null ? AppColors.inkMuted : AppColors.inkStrong,
              ),
        ),
      ),
    );
  }

  Future<void> _showBarangayPicker(List<Barangay> barangays) async {
    final sortedBarangays = [...barangays]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final selectedCode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose your barangay',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  itemCount: sortedBarangays.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final barangay = sortedBarangays[index];
                    final isSelected = barangay.code == _barangayCode;
                    return ListTile(
                      dense: true,
                      minVerticalPadding: 8,
                      title: Text(
                        barangay.name,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.inkStrong,
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check,
                              color: AppColors.primary,
                              size: 18,
                            )
                          : null,
                      onTap: () =>
                          Navigator.of(sheetContext).pop(barangay.code),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedCode != null && mounted) {
      setState(() => _barangayCode = selectedCode);
    }
  }

  Widget _renewalRecordField() {
    return ref.watch(myRecordsProvider).when(
          loading: () => const _AsyncPad(child: LinearProgressIndicator()),
          error: (error, _) => _AsyncError(
            label: 'Could not load your franchises.',
            onRetry: () => ref.invalidate(myRecordsProvider),
          ),
          data: (records) {
            final renewable =
                records.where((record) => !record.archived).toList();
            final validSelection =
                renewable.any((record) => record.id == _recordId);
            return DropdownButtonFormField<String>(
              key: ValueKey<String>('renewal-record-$_type'),
              initialValue: validSelection ? _recordId : null,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Franchise to renew'),
              hint: Text(
                renewable.isEmpty
                    ? 'No franchise available to renew'
                    : 'Select the franchise to renew',
              ),
              items: <DropdownMenuItem<String>>[
                for (final record in renewable)
                  DropdownMenuItem<String>(
                    value: record.id,
                    child: Text(
                      '${record.franchiseNumber} · ${record.plateNumber ?? ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: renewable.isEmpty
                  ? null
                  : (value) => setState(() => _recordId = value),
              validator: (value) => renewable.isEmpty
                  ? 'You have no franchise that can be renewed.'
                  : (value == null
                      ? 'Select the franchise being renewed.'
                      : null),
            );
          },
        );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
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
            maxLines: maxLines,
            textCapitalization: textCapitalization,
            decoration: InputDecoration(hintText: hint),
            validator: validator,
          ),
        ],
      ),
    );
  }

  Widget _stepOperator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Operator'),
        _field(
          label: 'First name',
          controller: _firstName,
          hint: 'Juan',
          textCapitalization: TextCapitalization.words,
          validator: (value) => _required(value, 'First name', max: 80),
        ),
        _field(
          label: 'Middle name (optional)',
          controller: _middleName,
          hint: 'Perez',
          textCapitalization: TextCapitalization.words,
          validator: (value) => _optional(value, 'Middle name', 80),
        ),
        _field(
          label: 'Last name',
          controller: _lastName,
          hint: 'Dela Cruz',
          textCapitalization: TextCapitalization.words,
          validator: (value) => _required(value, 'Last name', max: 80),
        ),
        _field(
          label: 'Contact number',
          controller: _contact,
          hint: '0917 123 4567',
          keyboardType: TextInputType.phone,
          validator: (value) =>
              _required(value, 'Contact number', min: 7, max: 20),
        ),
        _field(
          label: 'CTC / Cedula number',
          controller: _ctc,
          hint: 'e.g. 1234567',
          keyboardType: TextInputType.text,
          validator: (value) => _optional(value, 'CTC number', 60),
        ),
        _field(
          label: 'Address',
          controller: _address,
          hint: 'Purok / street, barangay',
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) => _required(value, 'Address', min: 5, max: 200),
        ),
        _field(
          label: 'E-mail (optional)',
          controller: _email,
          hint: 'name@example.com',
          keyboardType: TextInputType.emailAddress,
          validator: (value) => _optional(value, 'E-mail', 160),
        ),
      ],
    );
  }

  Widget _stepVehicle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Tricycle'),
        _field(
          label: 'Certificate of Registration (CR) number',
          controller: _crNumber,
          hint: 'e.g. 1234567890',
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          validator: (value) => _optional(value, 'CR number', 60),
        ),
        _field(
          label: 'Make',
          controller: _vehicleMake,
          hint: 'Honda',
          validator: (value) => _required(value, 'Vehicle make', max: 60),
        ),
        _field(
          label: 'Model',
          controller: _vehicleModel,
          hint: 'TMX',
          validator: (value) => _required(value, 'Vehicle model', max: 60),
        ),
        _field(
          label: 'Year',
          controller: _vehicleYear,
          hint: '2020',
          keyboardType: TextInputType.number,
          validator: _validateYear,
        ),
        _field(
          label: 'Color',
          controller: _vehicleColor,
          hint: 'Blue',
          textCapitalization: TextCapitalization.words,
          validator: (value) =>
              _required(value, 'Vehicle color', min: 2, max: 40),
        ),
        _field(
          label: 'Plate number',
          controller: _plate,
          hint: 'ABC 123',
          textCapitalization: TextCapitalization.characters,
          validator: (value) =>
              _required(value, 'Plate number', min: 3, max: 20),
        ),
        _field(
          label: 'Engine number',
          controller: _engine,
          hint: 'ENG-12345',
          validator: (value) =>
              _required(value, 'Engine number', min: 3, max: 40),
        ),
        _field(
          label: 'Chassis number',
          controller: _chassis,
          hint: 'CHS-12345',
          validator: (value) =>
              _required(value, 'Chassis number', min: 3, max: 40),
        ),
        _field(
          label: 'Seating capacity',
          controller: _seating,
          hint: '5',
          keyboardType: TextInputType.number,
          validator: _validateSeating,
        ),
        _field(
          label: 'MTOP number (optional)',
          controller: _mtop,
          validator: (value) => _optional(value, 'MTOP number', 60),
        ),
        _field(
          label: 'Body number (optional)',
          controller: _body,
          validator: (value) => _optional(value, 'Body number', 60),
        ),
      ],
    );
  }

  Widget _stepDocuments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Documentary requirements'),
        const Text(
          'Upload a clear photo or PDF of each requirement. PDF, JPEG or PNG, '
          'up to 10 MB each.',
          style:
              TextStyle(color: AppColors.inkMuted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final type in requiredDocumentTypes) ...[
          _DocumentTile(
            label: documentLabels[type] ?? type,
            upload: _uploads[type],
            uploading: _uploading.contains(type),
            error: _uploadErrors[type],
            onPick: () => _pickDocument(type),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }

  Widget _stepReview() {
    final submission = _buildSubmission();
    final now = DateTime.now();
    final dateStr = '${_monthName(now.month)} ${now.day}, ${now.year}';
    final applicantName = _fullName(
      submission.operatorFirstName,
      submission.operatorMiddleName,
      submission.operatorLastName,
    );
    final makeModel =
        '${_vehicleMake.text.trim()} ${_vehicleModel.text.trim()}'.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Application letter preview'),
        const Text(
          'Review the letter below before submitting. '
          'Your documents are attached automatically.',
          style:
              TextStyle(color: AppColors.inkMuted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.sm),
        // ---------- Paper letter ----------
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.box,
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date line
              const SizedBox(
                width: 200,
                child: Divider(color: Colors.black87, thickness: 0.8),
              ),
              const Text(
                'Date',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 24),
              // Addressee
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                  children: [
                    TextSpan(
                      text: 'Hon. Presiding Officer\n',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: 'and Hon. Members',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' of the Sangguniang Bayan\n'),
                    TextSpan(text: 'Municipality of Mabini\n'),
                    TextSpan(text: 'Mabini, Batangas'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Dear Sir/Madame:',
                style:
                    TextStyle(fontSize: 13, color: Colors.black87, height: 1.6),
              ),
              const SizedBox(height: 14),
              const Text(
                'I am applying for the approval of my application for franchise '
                'of that tricycle, more particularly described as follows:',
                textAlign: TextAlign.justify,
                style:
                    TextStyle(fontSize: 13, color: Colors.black87, height: 1.6),
              ),
              const SizedBox(height: 18),
              // Vehicle detail rows
              _letterFieldRow(
                'Certificate of Registration',
                _crNumber.text.trim(),
              ),
              _letterFieldRow('Model/Make', makeModel),
              _letterFieldRow('Engine No.', _engine.text.trim()),
              _letterFieldRow('Chassis No.', _chassis.text.trim()),
              _letterFieldRow('Plate No.', _plate.text.trim()),
              const SizedBox(height: 18),
              const Text(
                'The above-described tricycle is hereby requested to be given a '
                'franchise to be able to provide service of convenience to the public.',
                textAlign: TextAlign.justify,
                style:
                    TextStyle(fontSize: 13, color: Colors.black87, height: 1.6),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pertinent documents are attached herewith for your perusal.',
                textAlign: TextAlign.justify,
                style:
                    TextStyle(fontSize: 13, color: Colors.black87, height: 1.6),
              ),
              const SizedBox(height: 12),
              const Text(
                'Thank you and More Power.',
                style:
                    TextStyle(fontSize: 13, color: Colors.black87, height: 1.6),
              ),
              const SizedBox(height: 28),
              const Text(
                'Respectfully yours,',
                style:
                    TextStyle(fontSize: 13, color: Colors.black87, height: 1.6),
              ),
              const SizedBox(height: 36),
              // Signature block
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(
                      color: Colors.black87,
                      thickness: 0.8,
                    ),
                    Text(
                      applicantName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const Text(
                      'Applicant',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _letterInlineField('Contact No.', _contact.text.trim()),
              const SizedBox(height: 8),
              _letterInlineField('CTC.', _ctc.text.trim()),
              const SizedBox(height: 8),
              _letterInlineField('Date:', dateStr),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'By submitting, you confirm the information and documents are true '
          'and correct. The municipal office will review them and notify you of '
          'any change in status.',
          style:
              TextStyle(color: AppColors.inkMuted, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  /// Renders one vehicle-detail row in the letter: [Label]  :  [underlined value].
  Widget _letterFieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 158,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  height: 0.8,
                  color: Colors.black87,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Renders an inline label + underlined value row for the bottom of the letter.
  Widget _letterInlineField(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$label ',
          style:
              const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
        ),
        SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
              Container(height: 0.8, color: Colors.black87),
            ],
          ),
        ),
      ],
    );
  }

  static String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

// ---------------------------------------------------------------------------
// Field helpers
// ---------------------------------------------------------------------------

String? _required(String? value, String label, {int min = 1, int max = 200}) {
  final text = (value ?? '').trim();
  if (text.length < min) return '$label is required.';
  if (text.length > max) return '$label must not exceed $max characters.';
  return null;
}

String? _optional(String? value, String label, int max) {
  final text = (value ?? '').trim();
  if (text.length > max) return '$label must not exceed $max characters.';
  return null;
}

String? _validateYear(String? value) {
  final year = int.tryParse((value ?? '').trim());
  final maxYear = DateTime.now().year + 1;
  if (year == null) return 'Enter the vehicle year.';
  if (year < 1950 || year > maxYear) {
    return 'Year must be between 1950 and $maxYear.';
  }
  return null;
}

String? _validateSeating(String? value) {
  final capacity = int.tryParse((value ?? '').trim());
  if (capacity == null) return 'Enter the seating capacity.';
  if (capacity < 1 || capacity > 12) {
    return 'Capacity must be between 1 and 12.';
  }
  return null;
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _fullName(String first, String? middle, String last) {
  final parts = <String>[
    first,
    if (middle != null && middle.trim().isNotEmpty) middle.trim(),
    last,
  ];
  return parts.where((part) => part.trim().isNotEmpty).join(' ');
}

// ---------------------------------------------------------------------------
// Small widgets
// ---------------------------------------------------------------------------

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.titles});

  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Step ${step + 1} of ${titles.length} · ${titles[step]}',
            style: const TextStyle(
              color: AppColors.inkStrong,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: AppRadius.box,
            child: LinearProgressIndicator(
              value: (step + 1) / titles.length,
              minHeight: 6,
              backgroundColor: AppColors.greyFill,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.isFirst,
    required this.isLast,
    required this.submitting,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  final bool isFirst;
  final bool isLast;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (!isFirst) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: submitting ? null : onBack,
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: FilledButton(
              onPressed: submitting ? null : (isLast ? onSubmit : onNext),
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isLast ? 'Submit application' : 'Next'),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.box,
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Icon(icon,
                  color: selected ? AppColors.primary : AppColors.inkMuted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.inkStrong,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AsyncPad extends StatelessWidget {
  const _AsyncPad({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: child,
    );
  }
}

class _AsyncError extends StatelessWidget {
  const _AsyncError({required this.label, required this.onRetry});

  final String label;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.label,
    required this.upload,
    required this.uploading,
    required this.error,
    required this.onPick,
  });

  final String label;
  final ApplicationDocumentUpload? upload;
  final bool uploading;
  final String? error;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final uploaded = upload != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  uploaded
                      ? Icons.check_circle_outline
                      : Icons.upload_file_outlined,
                  color: uploaded ? AppColors.success : AppColors.inkMuted,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.inkStrong,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              error != null
                  ? error!
                  : uploaded
                      ? upload!.fileName
                      : 'PDF, JPEG or PNG, up to 10 MB',
              style: TextStyle(
                color: error != null ? AppColors.danger : AppColors.inkMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: uploading ? null : onPick,
              child: uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(uploaded ? 'Replace file' : 'Choose file'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown after `rpc_driver_submit_application` succeeds.
class _ApplicationSubmittedScreen extends StatelessWidget {
  const _ApplicationSubmittedScreen({required this.application});

  final FranchiseApplication application;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application submitted'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 64, color: AppColors.success),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Your application was received.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.inkStrong,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Reference number: ${application.applicationNumber}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'The municipal office will review your documents. You will '
                    'be notified here when the status changes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
