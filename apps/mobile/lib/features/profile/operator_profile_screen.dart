import 'package:sbtf_mobile/core/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_error.dart';
import '../../core/date_format.dart';
import '../../core/models/franchise_application.dart';
import '../../core/models/franchise_record.dart';
import '../../core/models/profile.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_chip.dart';

/// The operator profile module in the mobile app.
///
/// The operator can edit the descriptive half of their own profile — name,
/// contact number, address and barangay — and can read, but never change, the
/// authoritative half: the TODA they belong to, their membership record, their
/// franchise applications and the fees recorded against them.
///
/// The server-side RLS policies already refuse writes to `role` and
/// `account_status`; [ProfileService.updateMine] additionally never sends the
/// `toda_id`, so the UI restriction is not the only safeguard.
class OperatorProfileScreen extends ConsumerWidget {
  const OperatorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _LoadFailure(
            message: classifyAppError(error).message,
            onRetry: () => ref.invalidate(profileProvider),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(
                child: Text('No profile is linked to this account.'),
              );
            }
            return _ProfileBody(profile: profile);
          },
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(myApplicationsProvider);
    final recordsAsync = ref.watch(myRecordsProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: [
        _IdentityCard(profile: profile),
        const SizedBox(height: AppSpacing.md),

        const _SectionLabel('Personal details'),
        const SizedBox(height: AppSpacing.xs),
        _ProfileEditor(key: ValueKey(profile.id), profile: profile),

        const SizedBox(height: AppSpacing.md),
        const _SectionLabel('TODA membership'),
        const SizedBox(height: AppSpacing.xs),
        _MembershipCard(profile: profile),

        const SizedBox(height: AppSpacing.md),
        const _SectionLabel('Applications'),
        const SizedBox(height: AppSpacing.xs),
        applicationsAsync.when(
          loading: () => const _LoadingCard(),
          error: (error, _) => _ErrorCard(
            message: classifyAppError(error).message,
            onRetry: () => ref.invalidate(myApplicationsProvider),
          ),
          data: (applications) => applications.isEmpty
              ? const _EmptyCard(
                  icon: Icons.folder_open_outlined,
                  text: 'You have not filed a franchise application yet.',
                )
              : _ApplicationsCard(applications: applications),
        ),

        const SizedBox(height: AppSpacing.md),
        const _SectionLabel('Payments and fees'),
        const SizedBox(height: AppSpacing.xs),
        recordsAsync.when(
          loading: () => const _LoadingCard(),
          error: (error, _) => _ErrorCard(
            message: classifyAppError(error).message,
            onRetry: () => ref.invalidate(myRecordsProvider),
          ),
          data: (records) => records.isEmpty
              ? const _EmptyCard(
                  icon: Icons.receipt_long_outlined,
                  text: 'No franchise record or fee has been recorded yet.',
                )
              : _PaymentsCard(records: records),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.card,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            child: Text(
              profile.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  translate: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email,
                  translate: false,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 6),
                StatusChip(
                  label: _statusLabel(profile.accountStatus),
                  foreground: Colors.white,
                  background: Colors.white.withValues(alpha: 0.18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active account';
      case 'pending':
        return 'Awaiting approval';
      case 'suspended':
        return 'Suspended';
      default:
        return 'Inactive';
    }
  }
}

// ---------------------------------------------------------------------------
// Editable descriptive details
// ---------------------------------------------------------------------------

class _ProfileEditor extends ConsumerStatefulWidget {
  const _ProfileEditor({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<_ProfileEditor> {
  late final TextEditingController _firstName;
  late final TextEditingController _middleName;
  late final TextEditingController _lastName;
  late final TextEditingController _contactNumber;
  late final TextEditingController _addressLine;
  late String? _barangayCode;

  bool _saving = false;
  String? _error;

  static final RegExp _namePattern =
      RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ.'\-\s]{1,60}$");
  static final RegExp _contactPattern = RegExp(r'^[0-9+\-() ]{7,20}$');

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _firstName = TextEditingController(text: profile.firstName);
    _middleName = TextEditingController(text: profile.middleName ?? '');
    _lastName = TextEditingController(text: profile.lastName);
    _contactNumber = TextEditingController(text: profile.contactNumber ?? '');
    _addressLine = TextEditingController(text: profile.addressLine ?? '');
    _barangayCode = profile.barangayCode;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _contactNumber.dispose();
    _addressLine.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    final middleName = _middleName.text.trim();
    final contactNumber = _contactNumber.text.trim();
    final addressLine = _addressLine.text.trim();

    if (!_namePattern.hasMatch(firstName) || !_namePattern.hasMatch(lastName)) {
      setState(() => _error = 'Enter a valid first and last name.');
      return;
    }
    if (middleName.isNotEmpty && !_namePattern.hasMatch(middleName)) {
      setState(() => _error = 'Enter a valid middle name, or leave it blank.');
      return;
    }
    if (contactNumber.isNotEmpty && !_contactPattern.hasMatch(contactNumber)) {
      setState(() =>
          _error = 'Enter a valid contact number, for example 0917 123 4567.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(profileServiceProvider).updateMine(
            firstName: firstName,
            middleName: middleName,
            lastName: lastName,
            contactNumber: contactNumber,
            addressLine: addressLine,
            barangayCode: _barangayCode,
          );
      ref.invalidate(profileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your profile has been updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = classifyAppError(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final barangaysAsync = ref.watch(barangayListProvider);
    final barangays = barangaysAsync.valueOrNull ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              _InlineError(text: _error!),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _firstName,
                    label: 'First name',
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Field(
                    controller: _middleName,
                    label: 'Middle name',
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _Field(
              controller: _lastName,
              label: 'Last name',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.sm),
            _Field(
              controller: _contactNumber,
              label: 'Contact number',
              hint: '0917 123 4567',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.sm),
            _Field(
              controller: _addressLine,
              label: 'Address',
              hint: 'House number, street, sitio',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _barangayCode ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Barangay'),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('Not specified'),
                ),
                for (final barangay in barangays)
                  DropdownMenuItem<String>(
                    value: barangay.code,
                    child: Text(barangay.name, translate: false),
                  ),
              ],
              onChanged: barangaysAsync.isLoading
                  ? null
                  : (value) => setState(
                        () => _barangayCode =
                            value == null || value.isEmpty ? null : value,
                      ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your TODA, membership and account status are shown for reference only. '
              'They are set when you register and cannot be changed here — contact the '
              'Municipal Transport Office if any of them is wrong.',
              style: const TextStyle(
                color: AppColors.inkMuted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

// ---------------------------------------------------------------------------
// Read-only TODA membership
// ---------------------------------------------------------------------------

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final hasToda = (profile.todaId ?? '').isNotEmpty;
    final barangay = profile.barangayName ?? '—';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    hasToda
                        ? (profile.todaName ?? 'TODA on file')
                        : 'No TODA assigned',
                    translate: false,
                    style: const TextStyle(
                      color: AppColors.inkStrong,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (hasToda)
                  Text(
                    profile.todaCode ?? '',
                    translate: false,
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _ReadOnlyRow(label: 'Barangay', value: barangay),
            _ReadOnlyRow(
              label: 'Member since',
              value: formatDate(profile.createdAt),
            ),
            _ReadOnlyRow(
              label: 'Account status',
              value: profile.accountStatus,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'The TODA and membership details are controlled by the Municipal '
              'Transport Office. They cannot be edited from your profile.',
              style: TextStyle(
                color: AppColors.inkMuted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Applications
// ---------------------------------------------------------------------------

class _ApplicationsCard extends StatelessWidget {
  const _ApplicationsCard({required this.applications});

  final List<FranchiseApplication> applications;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < applications.length; index += 1) ...[
            if (index > 0) const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: AppColors.primary),
              title: Text(
                applications[index].applicationNumber,
                translate: false,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Text(
                '${_typeLabel(applications[index].applicationType)} · '
                'submitted ${formatDate(applications[index].submittedAt)}',
              ),
              trailing: applicationStatusChip(applications[index].status),
            ),
          ],
        ],
      ),
    );
  }

  static String _typeLabel(String type) =>
      type == ApplicationType.renewal ? 'Renewal' : 'New franchise';
}

// ---------------------------------------------------------------------------
// Payments
// ---------------------------------------------------------------------------

class _PaymentsCard extends StatelessWidget {
  const _PaymentsCard({required this.records});

  final List<FranchiseRecord> records;

  @override
  Widget build(BuildContext context) {
    final total = records.fold<double>(
      0,
      (sum, record) => sum + (record.amountPaid ?? 0),
    );

    return Card(
      child: Column(
        children: [
          for (var index = 0; index < records.length; index += 1) ...[
            if (index > 0) const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
              title: Text(
                records[index].franchiseNumber,
                translate: false,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Text(
                records[index].amountPaid == null
                    ? 'No fee recorded'
                    : '${_peso(records[index].amountPaid ?? 0)} · '
                        '${records[index].officialReceiptNumber == null ? 'no OR yet' : 'OR ${records[index].officialReceiptNumber}'}\n'
                        'Issued ${formatDate(records[index].issuedAt)} · '
                        'expires ${formatDate(records[index].expiresAt)}',
              ),
              isThreeLine: true,
            ),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total fees recorded',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  _peso(total),
                  translate: false,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkStrong,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _peso(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts.first;
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index += 1) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return '₱$buffer.${parts.last}';
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.inkMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
          ),
          Text(
            value,
            translate: false,
            style: const TextStyle(
              color: AppColors.inkStrong,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: AppRadius.chip,
      ),
      child: Text(
        text,
        translate: false,
        style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: AppColors.inkMuted),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              translate: false,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32, color: AppColors.danger),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              translate: false,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
