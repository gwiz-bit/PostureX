import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

/// Full-screen detail view for a single notification — opened by tapping a
/// row in [NotificationsScreen] instead of only marking it read inline.
/// Formats `workout_reminder`/`nutrition` bodies specially since those are
/// structured (comma-separated exercise list / a single tip) rather than
/// free-form text.
class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key, required this.notification});

  final AppNotification notification;

  IconData get _icon => switch (notification.type) {
        'payment' => Icons.workspace_premium_rounded,
        'workout' => Icons.fitness_center_rounded,
        'workout_reminder' => Icons.fitness_center_rounded,
        'nutrition' => Icons.restaurant_rounded,
        'break' => Icons.self_improvement_rounded,
        'daily_summary' => Icons.insights_rounded,
        'subscription' || 'subscription_expiry' => Icons.card_membership_rounded,
        'admin_broadcast' => Icons.campaign_rounded,
        _ => Icons.notifications_rounded,
      };

  String get _typeLabel => switch (notification.type) {
        'payment' => 'Payment',
        'workout' => 'Workout',
        'workout_reminder' => 'Workout reminder',
        'nutrition' => 'Nutrition',
        'break' => 'Break reminder',
        'daily_summary' => 'Daily summary',
        'subscription' || 'subscription_expiry' => 'Subscription',
        'admin_broadcast' => 'Announcement',
        _ => 'Notification',
      };

  String get _fullTimestamp {
    final d = notification.createdAt;
    final local = d.isUtc ? d.toLocal() : d;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm · ${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(_typeLabel),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryMuted,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    notification.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 62),
              child: Text(_fullTimestamp, style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            ),
            const SizedBox(height: 20),
            ..._buildBody(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    final body = notification.body;
    if (body == null || body.trim().isEmpty) return const [];

    if (notification.type == 'workout_reminder') {
      final exercises = body.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      return [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Today's exercises",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < exercises.length; i++) ...[
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      exercises[i],
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (i != exercises.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ];
    }

    return [
      SectionCard(
        child: Text(
          body,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5),
        ),
      ),
    ];
  }
}
