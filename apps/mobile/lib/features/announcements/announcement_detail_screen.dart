import 'package:flutter/material.dart';

import '../../core/date_format.dart';
import '../../core/models/announcement.dart';
import '../../core/theme.dart';

/// The full text of one office announcement.
class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({super.key, required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final published = announcement.publishedAt ?? announcement.createdAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Announcement')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: const BoxDecoration(
                gradient: AppGradients.hero,
                borderRadius: AppRadius.card,
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: 16,
                        color: Colors.white70,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Office announcement',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    announcement.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    formatDateTime(published),
                    style: TextStyle(
                      color: Colors.white.withAlpha(190),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  announcement.body,
                  style: const TextStyle(
                    color: AppColors.inkStrong,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            if (announcement.authorName != null &&
                announcement.authorName!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 14,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Posted by ${announcement.authorName}',
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
