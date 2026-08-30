import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/section_card.dart';
import '../../domain/entities/notification.dart';
import '../../notifications_module.dart';
import 'notification_detail_screen.dart';

/// Danh sách thông báo trong app (`GET /api/v1/notifications`).
///
/// Pop trả về `true` nếu có thông báo nào vừa được đánh dấu đã đọc, để màn gọi
/// nó (Home) biết mà cập nhật lại badge trên icon chuông — [UserSession] không
/// có listener nên không tự refresh được.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _controller = NotificationsModule.controller();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openDetail(AppNotification notification) async {
    await _controller.markRead(notification);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificationDetailScreen(notification: notification)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final hasUnread = _controller.notifications.any((n) => !n.isRead);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) Navigator.of(context).pop(_controller.didChangeAnything);
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              title: const Text('Notifications'),
              actions: [
                if (hasUnread)
                  TextButton(
                    onPressed: _controller.markAllRead,
                    child: const Text('Mark all read'),
                  ),
              ],
            ),
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: _controller.load,
                child: _buildBody(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_controller.errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          SectionCard(
            child: Column(
              children: [
                Text(_controller.errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                TextButton(onPressed: _controller.load, child: const Text('Retry')),
              ],
            ),
          ),
        ],
      );
    }

    final notifications = _controller.notifications;

    if (notifications.isEmpty) {
      // Vẫn phải là ListView (không phải Center) để RefreshIndicator kéo được
      // khi danh sách rỗng.
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
        children: const [
          Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.textTertiary),
          SizedBox(height: 12),
          Text(
            'No notifications yet',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _NotificationTile(
        notification: notifications[index],
        onTap: () => _openDetail(notifications[index]),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  /// Icon theo `type` do backend gắn. Danh sách giá trị nằm ở
  /// `app/crud/notification.py` — thêm loại mới ở đó thì thêm nhánh ở đây.
  IconData get _icon => switch (notification.type) {
        'payment' => Icons.workspace_premium_rounded,
        'workout' => Icons.fitness_center_rounded,
        'break' => Icons.self_improvement_rounded,
        'daily_summary' => Icons.insights_rounded,
        'subscription' || 'subscription_expiry' => Icons.card_membership_rounded,
        _ => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;

    return GestureDetector(
      onTap: onTap,
      child: SectionCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: unread ? AppColors.primaryMuted : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                _icon,
                size: 20,
                color: unread ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      color: unread ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (notification.body != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.body!,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _relativeTime(notification.createdAt),
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// MySQL `DATETIME` không lưu timezone nên backend trả timestamp không có hậu
/// tố `Z`; `DateTime.parse` sẽ coi nó là giờ local. Backend ghi bằng giờ UTC,
/// nên phải ép về UTC trước khi so, nếu không mọi thông báo sẽ lệch 7 tiếng.
String _relativeTime(DateTime createdAt) {
  final utc = createdAt.isUtc ? createdAt : DateTime.utc(
        createdAt.year,
        createdAt.month,
        createdAt.day,
        createdAt.hour,
        createdAt.minute,
        createdAt.second,
      );
  final diff = DateTime.now().toUtc().difference(utc);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
}
