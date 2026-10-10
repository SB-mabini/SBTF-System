import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';

/// The landing screen for a signed-in driver/operator.
///
/// Slices 1–2 deliver authentication and this shell only. Every feature tile is
/// labelled honestly with the slice that will deliver it and a "soon" badge —
/// none of them pretend to work yet.
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('SBTF Mobile'),
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
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 40, color: AppColors.danger),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Could not load your profile.',
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(profileProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (profile) => ListView(
            padding: const EdgeInsets.all(AppSpacing.sm),
            children: [
              _ProfileHeader(
                name: profile?.fullName ?? 'Driver',
                initials: profile?.initials ?? '?',
                active: profile?.isActive ?? false,
              ),
              const SizedBox(height: AppSpacing.md),
              ..._featureTiles,
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> get _featureTiles => const [
        _FeatureTile(
          icon: Icons.note_add_outlined,
          title: 'New franchise application',
          slice: 'Slice 3',
        ),
        _FeatureTile(
          icon: Icons.autorenew_outlined,
          title: 'Renewal application',
          slice: 'Slice 3',
        ),
        _FeatureTile(
          icon: Icons.track_changes_outlined,
          title: 'My application status',
          slice: 'Slice 4',
        ),
        _FeatureTile(
          icon: Icons.description_outlined,
          title: 'My documents',
          slice: 'Slice 5',
        ),
        _FeatureTile(
          icon: Icons.verified_outlined,
          title: 'Certificate & QR code',
          slice: 'Slice 6',
        ),
        _FeatureTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          slice: 'Slice 7',
        ),
      ];
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.initials,
    required this.active,
  });

  final String name;
  final String initials;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.surface,
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      active
                          ? Icons.check_circle_outlined
                          : Icons.pause_circle_outline,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        active
                            ? 'Driver / operator · account active'
                            : 'Driver / operator · account not active',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.slice,
  });

  final IconData icon;
  final String title;
  final String slice;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: InkWell(
        onTap: () {}, // InkWell adds the pressed state overlay
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.inkStrong,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              _SoonBadge(slice: slice),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge({required this.slice});

  final String slice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(AppSpacing.unit),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Soon · $slice',
        style: const TextStyle(
          color: AppColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
