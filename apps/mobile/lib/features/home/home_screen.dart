import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/franchise_application.dart';
import '../../core/models/profile.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/error_view.dart';
import '../application/application_form_screen.dart';
import '../application/application_list_screen.dart';
import '../appointments/appointment_list_screen.dart';
import '../certificate/certificate_list_screen.dart';
import '../documents/document_manager_screen.dart';
import '../notifications/notification_list_screen.dart';

/// The landing screen for a signed-in driver/operator with bottom navigation.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        backgroundColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.compact,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Log Out?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkStrong,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Are you sure you want to log out?',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.inkMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.greyFill,
                        foregroundColor: AppColors.inkStrong,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.input,
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.dangerFill,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.input,
                        ),
                      ),
                      child: const Text(
                        'Log out',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  void _openApplication(BuildContext context, String? applicationType) {
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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final unread =
        ref.watch(unreadNotificationCountStreamProvider).valueOrNull ?? 0;
    final appointments =
        ref.watch(myAppointmentsStreamProvider).valueOrNull ?? const [];
    final upcoming =
        appointments.where((appointment) => appointment.isUpcoming).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mabini Franchise'),
        actions: [
          Stack(
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => _openNotifications(context),
              ),
              if (unread > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.dangerFill,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
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
          data: (profile) => IndexedStack(
            index: _currentIndex,
            children: [
              _HomeTab(
                profile: profile,
                unread: unread,
                upcoming: upcoming,
                onOpenApplication: (type) =>
                    _openApplication(context, type),
                onOpenStatus: () => _openStatus(context),
                onOpenAppointments: () => _openAppointments(context),
                onOpenDocuments: () => _openDocuments(context),
                onOpenCertificates: () => _openCertificates(context),
                onOpenNotifications: () => _openNotifications(context),
              ),
              const SizedBox.shrink(),
              _TrackTab(
                upcoming: upcoming,
                onOpenAppointments: () => _openAppointments(context),
                onOpenStatus: () => _openStatus(context),
              ),
              _DocumentsTab(
                onOpenDocuments: () => _openDocuments(context),
                onOpenCertificates: () => _openCertificates(context),
              ),

            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == 1) {
            _openApplication(context, null);
            return;
          }
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryTint,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_add_outlined),
            selectedIcon: Icon(Icons.note_add, color: AppColors.primary),
            label: 'Apply',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_outlined),
            selectedIcon: Icon(Icons.track_changes, color: AppColors.primary),
            label: 'Track',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder, color: AppColors.primary),
            label: 'Documents',
          ),

        ],
      ),
    );
  }
}

/// Home tab content
class _HomeTab extends ConsumerWidget {
  const _HomeTab({
    required this.profile,
    required this.unread,
    required this.upcoming,
    required this.onOpenApplication,
    required this.onOpenStatus,
    required this.onOpenAppointments,
    required this.onOpenDocuments,
    required this.onOpenCertificates,
    required this.onOpenNotifications,
  });

  final Profile? profile;
  final int unread;
  final int upcoming;
  final void Function(String) onOpenApplication;
  final VoidCallback onOpenStatus;
  final VoidCallback onOpenAppointments;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenCertificates;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications =
        ref.watch(myApplicationsStreamProvider).valueOrNull ?? const [];
    final latest = applications.isNotEmpty ? applications.first : null;

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
        _LatestApplicationCard(
          application: latest,
          onOpenStatus: onOpenStatus,
          onOpenApplication: onOpenApplication,
        ),
      ],
    );
  }
}

/// Track tab - Applications and Appointments
class _TrackTab extends StatelessWidget {
  const _TrackTab({
    required this.upcoming,
    required this.onOpenAppointments,
    required this.onOpenStatus,
  });

  final int upcoming;
  final VoidCallback onOpenAppointments;
  final VoidCallback onOpenStatus;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: [
        const Text(
          'Track & Updates',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.inkStrong,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _BottomNavTile(
          icon: Icons.event_available_outlined,
          title: 'My Appointments',
          subtitle: 'Scheduled visits and hearings',
          onTap: onOpenAppointments,
          badge: upcoming > 0 ? _CountBadge(count: upcoming) : null,
        ),
        const SizedBox(height: 8),
        _BottomNavTile(
          icon: Icons.track_changes_outlined,
          title: 'My Application Status',
          subtitle: 'Follow your submissions',
          onTap: onOpenStatus,
        ),
      ],
    );
  }
}

/// Documents tab - Documents and Certificates
class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({
    required this.onOpenDocuments,
    required this.onOpenCertificates,
  });

  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenCertificates;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: [
        const Text(
          'Documents & Certificates',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.inkStrong,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _BottomNavTile(
          icon: Icons.description_outlined,
          title: 'My Documents',
          subtitle: 'Manage your uploaded files',
          onTap: onOpenDocuments,
        ),
        const SizedBox(height: 8),
        _BottomNavTile(
          icon: Icons.verified_outlined,
          title: 'Certificate & QR Code',
          subtitle: 'View your franchise certificate',
          onTap: onOpenCertificates,
        ),
      ],
    );
  }
}

/// More tab
class _MoreTab extends StatelessWidget {
  const _MoreTab({
    required this.unread,
    required this.onOpenNotifications,
    required this.onSignOut,
  });

  final int unread;
  final VoidCallback onOpenNotifications;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: [
        const Text(
          'More',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.inkStrong,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _BottomNavTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Decisions and reminders',
          onTap: onOpenNotifications,
          badge: unread > 0 ? _CountBadge(count: unread) : null,
        ),
        const SizedBox(height: 8),
        _BottomNavTile(
          icon: Icons.logout,
          title: 'Sign Out',
          subtitle: 'Sign out of your account',
          onTap: onSignOut,
        ),
      ],
    );
  }
}

/// Latest application card shown on the home tab in place of quick actions.
class _LatestApplicationCard extends StatelessWidget {
  const _LatestApplicationCard({
    required this.application,
    required this.onOpenStatus,
    required this.onOpenApplication,
  });

  final FranchiseApplication? application;
  final VoidCallback onOpenStatus;
  final void Function(String) onOpenApplication;

  @override
  Widget build(BuildContext context) {
    final app = application;
    if (app == null) {
      return _NoApplicationPlaceholder(onOpenApplication: onOpenApplication);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: application number + status badge
        _ApplicationHeaderCard(application: app),
        const SizedBox(height: AppSpacing.xs),
        // Details table
        _ApplicationDetailsCard(application: app),
        const SizedBox(height: AppSpacing.xs),
        // View all link
        Center(
          child: TextButton.icon(
            onPressed: onOpenStatus,
            icon: const Icon(Icons.list_alt_outlined, size: 16),
            label: const Text('View all applications'),
          ),
        ),
      ],
    );
  }
}

/// Header card: application number + status chip (mirrors the screenshot).
class _ApplicationHeaderCard extends StatelessWidget {
  const _ApplicationHeaderCard({required this.application});

  final FranchiseApplication application;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  application.applicationNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                if (application.submittedAt != null)
                  Text(
                    'Submitted ${_formatDateTime(application.submittedAt!)}',
                    style: TextStyle(
                      color: Colors.white.withAlpha(190),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          _StatusBadge(status: application.status),
        ],
      ),
    );
  }
}

/// Status pill badge.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon, String label) = switch (status) {
      ApplicationStatus.approved => (
          AppColors.successTint,
          AppColors.success,
          Icons.check_circle_outline,
          'Approved',
        ),
      ApplicationStatus.rejected => (
          AppColors.dangerTint,
          AppColors.danger,
          Icons.cancel_outlined,
          'Rejected',
        ),
      _ => (
          AppColors.accentTint,
          AppColors.warning,
          Icons.hourglass_top_outlined,
          'Pending',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Details table card (mirrors the screenshot's "Application details" section).
class _ApplicationDetailsCard extends StatelessWidget {
  const _ApplicationDetailsCard({required this.application});

  final FranchiseApplication application;

  @override
  Widget build(BuildContext context) {
    final vehicleLabel =
        '${application.vehicleMake} ${application.vehicleModel}'
        ' (${application.vehicleYear})';

    final rows = <(String, String)>[
      ('Type', application.isRenewal ? 'Renewal' : 'New franchise'),
      if (application.todaName != null) ('TODA', application.todaName!),
      ('Operator', application.operatorFullName),
      ('Contact', application.operatorContactNumber),
      ('Vehicle', vehicleLabel),
      ('Plate number', application.plateNumber),
      if (application.submittedAt != null)
        ('Submitted', _formatDateTime(application.submittedAt!)),
      if (application.reviewedAt != null)
        ('Reviewed', _formatDateTime(application.reviewedAt!)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.compact,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Application details',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.inkStrong,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Divider(),
            const SizedBox(height: 4),
            ...rows.map(
              (row) => _DetailRow(label: row.$1, value: row.$2),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single label/value row inside the details card.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.inkMuted,
              ),
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

/// Placeholder when the user has not submitted any application yet.
class _NoApplicationPlaceholder extends StatelessWidget {
  const _NoApplicationPlaceholder({required this.onOpenApplication});

  final void Function(String) onOpenApplication;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.note_add_outlined,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'No applications yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.inkStrong,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Start your franchise journey by filing\na new application.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.inkMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: () =>
                  onOpenApplication(ApplicationType.newFranchise),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Apply now'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats a [DateTime] as "d MMM yyyy, h:mm am/pm" (e.g., "15 Oct 2026, 2:27 PM").
String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${local.day} ${months[local.month - 1]} ${local.year}, $hour:$minute $period';
}

/// Tile for bottom nav tabs
class _BottomNavTile extends StatelessWidget {
  const _BottomNavTile({
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
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
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
                        fontSize: 15,
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

/// The gradient identity card at the top of the dashboard
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

/// The count on the notifications and appointments rows.
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
