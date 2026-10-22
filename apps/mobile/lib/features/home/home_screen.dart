import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/franchise_application.dart';
import '../../core/models/profile.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/section_header.dart';
import '../application/application_form_screen.dart';
import '../application/application_list_screen.dart';
import '../appointments/appointment_list_screen.dart';
import '../certificate/certificate_list_screen.dart';
import '../documents/document_manager_screen.dart';
import '../notifications/notification_list_screen.dart';

/// The landing screen for a signed-in driver/operator.
///
/// Slices 1–2 delivered authentication and this shell. Slice 3 (the
/// new/renewal wizard), slice 4 (the application status tracker), slice 5 (the
/// document manager), slice 6 (certificates, QR codes and the scanner) and slice
/// 7 (notifications) are now live — every destination is reachable from the
/// dashboard below. The hero card shows who is signed in and the notifications
/// row carries the live unread count.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to use the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dangerFill,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Even if the network call fails the AuthGate will re-evaluate on the
      // next auth event; surface nothing rather than block sign-out.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    // Live unread count for the notifications row. A stream that cannot start
    // (offline, or the table is missing) simply leaves the badge off.
    final unread =
        ref.watch(unreadNotificationCountStreamProvider).valueOrNull ?? 0;
    // Appointments the driver still has to attend. The same stream feeds the
    // appointments list, so the app opens a single Realtime channel either
    // way; a stream that cannot start simply leaves the badge off.
    final appointments =
        ref.watch(myAppointmentsStreamProvider).valueOrNull ?? const [];
    final upcoming =
        appointments.where((appointment) => appointment.isUpcoming).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mabini Franchise'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CenteredScrollView(
            child: ErrorView(
              error: error,
              onRetry: () => ref.invalidate(profileProvider),
            ),
          ),
          data: (profile) => _dashboard(context, unread, upcoming, profile),
        ),
      ),
    );
  }

  Widget _dashboard(
      BuildContext context, int unread, int upcoming, Profile? profile) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      children: [
        _HeroCard(
          name: profile?.fullName ?? 'Driver',
          initials: profile?.initials ?? '?',
          email: profile?.email,
          active: profile?.isActive ?? false,
        ),
        const SizedBox(height: AppSpacing.sm),
        const SectionHeader('Services'),
        _RecordTile(
          icon: Icons.note_add_outlined,
          title: 'New franchise application',
          subtitle: 'Apply for a new tricycle franchise',
          onTap: () => _openApplication(context, ApplicationType.newFranchise),
        ),
        const SizedBox(height: 6),
        _RecordTile(
          icon: Icons.autorenew_outlined,
          title: 'Renewal application',
          subtitle: 'Renew an existing franchise',
          onTap: () => _openApplication(context, ApplicationType.renewal),
        ),
        const SizedBox(height: 6),
        _RecordTile(
          icon: Icons.description_outlined,
          title: 'My documents',
          subtitle: 'Manage your uploaded files',
          onTap: () => _openDocuments(context),
        ),
        const SizedBox(height: 6),
        _RecordTile(
          icon: Icons.verified_outlined,
          title: 'Certificate & QR code',
          subtitle: 'View your franchise certificate',
          onTap: () => _openCertificates(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        const SectionHeader('Track & updates'),
        _RecordTile(
          icon: Icons.event_available_outlined,
          title: 'My appointments',
          subtitle: 'Scheduled visits and hearings',
          onTap: () => _openAppointments(context),
          badge: upcoming > 0 ? _CountBadge(count: upcoming) : null,
        ),
        const SizedBox(height: 6),
        _RecordTile(
          icon: Icons.track_changes_outlined,
          title: 'My application status',
          subtitle: 'Follow your submissions',
          onTap: () => _openStatus(context),
        ),
        const SizedBox(height: 6),
        _RecordTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Decisions and reminders',
          onTap: () => _openNotifications(context),
          badge: unread > 0 ? _CountBadge(count: unread) : null,
        ),
      ],
    );
  }

  void _openApplication(BuildContext context, String applicationType) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApplicationFormScreen(applicationType: applicationType),
      ),
    );
  }

  void _openStatus(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ApplicationListScreen(),
      ),
    );
  }

  void _openAppointments(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AppointmentListScreen(),
      ),
    );
  }

  void _openDocuments(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DocumentManagerScreen(),
      ),
    );
  }

  void _openCertificates(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CertificateListScreen(),
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationListScreen(),
      ),
    );
  }
}

/// The gradient identity card at the top of the dashboard: who is signed in,
/// their contact address and account state.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.name,
    required this.initials,
    required this.active,
    this.email,
  });

  final String name;
  final String initials;
  final String? email;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final email = this.email;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: AppRadius.hero,
        boxShadow: AppShadows.card,
      ),
      child: Stack(
        children: [
          // A faint municipal seal watermark, purely decorative.
          Positioned(
            right: -24,
            top: -24,
            child: Icon(
              Icons.account_balance,
              size: 156,
              color: Colors.white.withAlpha(12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroAvatar(initials: initials),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (email != null && email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withAlpha(190),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: 6,
                        children: [
                          const _HeroPill(
                            icon: Icons.badge_outlined,
                            label: 'Driver / Operator',
                          ),
                          _HeroPill(
                            icon: active
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                            label: active ? 'Active' : 'Not active',
                          ),
                        ],
                      ),
                    ],
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

/// The initials avatar framing the driver's identity, ringed in the gold seal
/// colour.
class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.accent, width: 2.5),
        boxShadow: AppShadows.card,
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A translucent pill used inside the hero for the role and account state.
class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        borderRadius: AppRadius.chip,
        border: Border.all(color: Colors.white.withAlpha(46)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-width row in the "Track & updates" group: a tinted icon, a title with
/// an optional supporting line, an optional trailing badge and a chevron.
class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// Optional trailing indicator, shown before the chevron — the notifications
  /// row uses it for the unread count.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final badge = this.badge;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.compact,
            vertical: 10,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: AppRadius.input,
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.inkStrong,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null) ...[
                badge,
                const SizedBox(width: AppSpacing.xs),
              ],
              const Icon(Icons.chevron_right, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The count on the notifications and appointments rows. Hidden at zero,
/// capped so a large number cannot stretch the row.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.dangerFill,
        borderRadius: AppRadius.chip,
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
