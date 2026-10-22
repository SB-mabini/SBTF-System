import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_error.dart';
import '../../core/appointment_format.dart';
import '../../core/date_format.dart';
import '../../core/models/appointment.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_chip.dart';
import '../application/application_detail_screen.dart';

/// One appointment: when it is, where to go, and what the office recorded —
/// slice 9.
///
/// The appointment is read-only. The staff schedule and close it out from the
/// web console; the driver can only read it, which is why this screen offers
/// no booking, rescheduling or cancellation action.
class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appointment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            _Header(appointment: appointment),
            const SizedBox(height: AppSpacing.md),
            const _SectionTitle('Details'),
            _InfoCard(appointment: appointment),
            if (appointment.hasRemark) ...[
              const SizedBox(height: AppSpacing.md),
              const _SectionTitle('Outcome'),
              _NoteCard(
                icon: Icons.task_alt,
                text: appointment.outcome!,
                tone: AppColors.success,
              ),
            ],
            if ((appointment.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const _SectionTitle('Note from the office'),
              _NoteCard(
                icon: Icons.sticky_note_2_outlined,
                text: appointment.notes!,
                tone: AppColors.info,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            const _SectionTitle('Your application'),
            _ApplicationCard(appointment: appointment),
          ],
        ),
      ),
    );
  }
}

/// The identity band at the top: what kind of visit this is, when it is and
/// what state it is in.
class _Header extends StatelessWidget {
  const _Header({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final dayLabel = appointmentDayLabel(appointment.scheduledAt);

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
                  appointmentKindLabel(appointment.kind),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              appointmentStatusChip(appointment.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatDateTime(appointment.scheduledAt),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          if (dayLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              dayLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Type', appointmentKindLabel(appointment.kind)),
      ('Date and time', formatDateTime(appointment.scheduledAt)),
      (
        'Venue',
        appointment.venue.isEmpty ? 'To be announced' : appointment.venue
      ),
      (
        'Application',
        (appointment.applicationNumber ?? '').isEmpty
            ? '—'
            : appointment.applicationNumber!
      ),
      ('Status', appointmentStatusLabel(appointment.status)),
      ('Closed out on', formatDateTime(appointment.completedAt)),
      ('Booked on', formatDateTime(appointment.createdAt)),
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

/// A remark from the office — the recorded outcome, or a note.
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.icon,
    required this.text,
    required this.tone,
  });

  final IconData icon;
  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: tone),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.inkStrong,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The application this appointment belongs to, with a way into its tracker.
class _ApplicationCard extends ConsumerStatefulWidget {
  const _ApplicationCard({required this.appointment});

  final Appointment appointment;

  @override
  ConsumerState<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends ConsumerState<_ApplicationCard> {
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final number = widget.appointment.applicationNumber;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              (number ?? '').isEmpty
                  ? 'This appointment belongs to one of your applications.'
                  : 'This appointment belongs to application $number.',
              style: const TextStyle(
                color: AppColors.inkStrong,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: _opening ? null : _open,
              icon: _opening
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.track_changes_outlined),
              label: const Text('Open application status'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open() async {
    setState(() => _opening = true);

    final application = await _load(
      () => ref
          .read(applicationServiceProvider)
          .getById(widget.appointment.applicationId),
    );
    if (!mounted) return;

    setState(() => _opening = false);
    if (application == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApplicationDetailScreen(application: application),
      ),
    );
  }

  /// Loads the application, surfacing a friendly message when it is gone or
  /// the network fails.
  Future<T?> _load<T>(Future<T?> Function() fetch) async {
    try {
      final value = await fetch();
      if (value == null && mounted) {
        _showMessage('That application is no longer available.');
      }
      return value;
    } on AppFailure catch (failure) {
      if (mounted) _showMessage(failure.message, isError: true);
      return null;
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
