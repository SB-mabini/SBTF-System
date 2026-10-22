import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/appointment_format.dart';
import '../../core/date_format.dart';
import '../../core/models/appointment.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/status_chip.dart';
import '../application/application_list_screen.dart';
import 'appointment_detail_screen.dart';

/// Which half of the schedule the list shows.
///
/// Mirrors the web console's staff appointments page, which splits the same
/// way — but the split here is about what the driver has to do: an
/// appointment is "upcoming" while it still stands and its date has not
/// passed, and everything else (completed, missed, called off) is "past".
enum AppointmentScope { upcoming, past }

/// The driver's appointments — slice 9.
///
/// Backed by [myAppointmentsStreamProvider], so an appointment booked by the
/// municipal office reaches the phone without a manual refresh; RLS limits
/// the stream to the caller's own rows. A row opens the appointment's detail.
class AppointmentListScreen extends ConsumerStatefulWidget {
  const AppointmentListScreen({super.key});

  @override
  ConsumerState<AppointmentListScreen> createState() =>
      _AppointmentListScreenState();
}

class _AppointmentListScreenState extends ConsumerState<AppointmentListScreen> {
  AppointmentScope _scope = AppointmentScope.upcoming;

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(myAppointmentsStreamProvider);

    // The counts on the scope tabs, so the driver can see at a glance that a
    // visit is waiting in the other half of the schedule.
    final appointments = appointmentsAsync.valueOrNull ?? const <Appointment>[];
    final upcomingCount = appointments.where((a) => a.isUpcoming).length;
    final pastCount = appointments.length - upcomingCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                0,
              ),
              child: _ScopeTabs(
                scope: _scope,
                upcomingCount: upcomingCount,
                pastCount: pastCount,
                onChanged: (scope) => setState(() => _scope = scope),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(myAppointmentsStreamProvider.future),
                child: appointmentsAsync.when(
                  loading: () => const CenteredScrollView(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => CenteredScrollView(
                    child: ErrorView(
                      error: error,
                      onRetry: () =>
                          ref.invalidate(myAppointmentsStreamProvider),
                    ),
                  ),
                  data: (appointments) => _body(context, appointments),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<Appointment> appointments) {
    final visible = _visible(appointments);

    if (visible.isEmpty) return _Empty(scope: _scope);

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: visible.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _Summary(count: visible.length, scope: _scope);
        }
        final appointment = visible[index - 1];
        return _AppointmentCard(
          appointment: appointment,
          onTap: () => _openDetail(context, appointment),
        );
      },
    );
  }

  /// The appointments of the current scope, in the order a driver needs them:
  /// the next visit first, the most recent visit first.
  List<Appointment> _visible(List<Appointment> appointments) {
    final scoped =
        appointments.where((a) => _matches(a, _scope)).toList(growable: false);
    scoped.sort(_scope == AppointmentScope.upcoming
        ? (a, b) => a.scheduledAt.compareTo(b.scheduledAt)
        : (a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return scoped;
  }

  bool _matches(Appointment appointment, AppointmentScope scope) {
    return scope == AppointmentScope.upcoming
        ? appointment.isUpcoming
        : !appointment.isUpcoming;
  }

  void _openDetail(BuildContext context, Appointment appointment) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentDetailScreen(appointment: appointment),
      ),
    );
  }
}

/// The two scopes, as bordered pills — the same shape as the web console's
/// staff appointments tabs.
class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs({
    required this.scope,
    required this.upcomingCount,
    required this.pastCount,
    required this.onChanged,
  });

  final AppointmentScope scope;
  final int upcomingCount;
  final int pastCount;
  final ValueChanged<AppointmentScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ScopeTab(
          label: 'Upcoming',
          count: upcomingCount,
          selected: scope == AppointmentScope.upcoming,
          onTap: () => onChanged(AppointmentScope.upcoming),
        ),
        const SizedBox(width: AppSpacing.xs),
        _ScopeTab(
          label: 'Past',
          count: pastCount,
          selected: scope == AppointmentScope.past,
          onTap: () => onChanged(AppointmentScope.past),
        ),
      ],
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.primaryTint : AppColors.surface,
        borderRadius: AppRadius.box,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.box,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.compact,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.box,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.inkMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.greyFill,
                      borderRadius: AppRadius.chip,
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "2 upcoming appointments" — how many the scope holds.
class _Summary extends StatelessWidget {
  const _Summary({required this.count, required this.scope});

  final int count;
  final AppointmentScope scope;

  @override
  Widget build(BuildContext context) {
    final noun = scope == AppointmentScope.upcoming ? 'appointment' : 'visit';
    final text = scope == AppointmentScope.upcoming
        ? '$count upcoming $noun${count == 1 ? '' : 's'}.'
        : '$count past $noun${count == 1 ? '' : 's'}.';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
      ),
    );
  }
}

/// What a driver sees when the scope holds nothing.
class _Empty extends StatelessWidget {
  const _Empty({required this.scope});

  final AppointmentScope scope;

  @override
  Widget build(BuildContext context) {
    if (scope == AppointmentScope.past) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No past appointments',
        message: 'Completed, missed and cancelled appointments appear here '
            'once the municipal office closes them out.',
      );
    }
    return EmptyState(
      icon: Icons.event_available_outlined,
      title: 'No upcoming appointments',
      message: 'When the municipal office schedules an evaluation, a hearing '
          'or a document-release visit for your application, it will appear '
          'here with the date, time and venue.',
      action: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ApplicationListScreen(),
          ),
        ),
        icon: const Icon(Icons.track_changes_outlined),
        label: const Text('Check my application'),
      ),
    );
  }
}

/// One appointment: what it is, when it is, where to go.
class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, required this.onTap});

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dayLabel = appointmentDayLabel(appointment.scheduledAt);
    final applicationNumber = appointment.applicationNumber;

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
                      appointmentKindLabel(appointment.kind),
                      style: const TextStyle(
                        color: AppColors.inkStrong,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  appointmentStatusChip(appointment.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _IconLine(
                icon: Icons.event_outlined,
                text: dayLabel.isEmpty
                    ? formatDateTime(appointment.scheduledAt)
                    : '${formatDateTime(appointment.scheduledAt)} · $dayLabel',
              ),
              const SizedBox(height: 2),
              _IconLine(
                icon: Icons.place_outlined,
                text: appointment.venue.isEmpty
                    ? 'Venue to be announced'
                    : appointment.venue,
              ),
              if (applicationNumber != null &&
                  applicationNumber.isNotEmpty) ...[
                const SizedBox(height: 2),
                _IconLine(
                  icon: Icons.description_outlined,
                  text: applicationNumber,
                ),
              ],
              if (appointment.hasRemark) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  appointment.outcome!,
                  style: const TextStyle(
                    color: AppColors.inkStrong,
                    fontSize: 13,
                    height: 1.4,
                  ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
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
