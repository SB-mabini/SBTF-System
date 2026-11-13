import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_format.dart';
import '../../core/models/announcement.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import 'announcement_detail_screen.dart';

/// Office announcements addressed to the driver.
///
/// Backed by [announcementsStreamProvider]. Announcements are also delivered as
/// notifications, but the feed is kept here so the full text survives even after
/// a driver clears their notifications. RLS only returns published rows whose
/// audience resolves to the signed-in driver.
class AnnouncementListScreen extends ConsumerWidget {
  const AnnouncementListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(announcementsStreamProvider.future),
          child: announcementsAsync.when(
            loading: () => const CenteredScrollView(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => CenteredScrollView(
              child: ErrorView(
                error: error,
                onRetry: () => ref.invalidate(announcementsStreamProvider),
              ),
            ),
            data: (announcements) {
              if (announcements.isEmpty) {
                return const EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No announcements yet',
                  message: 'Notices from the franchising office — renewal '
                      'windows, assemblies and office advisories — appear here.',
                );
              }
              final sorted = [...announcements]..sort(_newestFirst);
              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.sm),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: sorted.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _Summary(count: sorted.length);
                  }
                  final announcement = sorted[index - 1];
                  return _AnnouncementCard(
                    announcement: announcement,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AnnouncementDetailScreen(
                            announcement: announcement),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Newest first; a row without a timestamp sinks rather than jumping.
  int _newestFirst(Announcement a, Announcement b) {
    final left = a.publishedAt ?? a.createdAt;
    final right = b.publishedAt ?? b.createdAt;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        '$count announcement${count == 1 ? '' : 's'} for you.',
        style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
      ),
    );
  }
}

/// One announcement: title, a short preview and when it was published.
class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement, required this.onTap});

  final Announcement announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final published = announcement.publishedAt ?? announcement.createdAt;
    final isRecent = published != null &&
        DateTime.now().difference(published.toLocal()).inDays < 3;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: AppRadius.box,
                    ),
                    child: const Icon(
                      Icons.campaign_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      announcement.title,
                      style: const TextStyle(
                        color: AppColors.inkStrong,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (isRecent) ...[
                    const SizedBox(width: AppSpacing.xs),
                    const _NewBadge(),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                announcement.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.inkStrong,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 13,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      formatDateTime(published),
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.inkMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.card,
      ),
      child: const Text(
        'New',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
