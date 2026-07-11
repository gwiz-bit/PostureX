import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../models/workout_plan.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'notifications_screen.dart';
import '../widgets/app_logo.dart';
import '../widgets/icon_badge.dart';
import '../widgets/plan_calendar.dart';
import '../widgets/score_ring.dart';
import '../widgets/section_card.dart';
import '../widgets/weekly_bar_chart.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _weekData = [
    DayScore(day: 'M', value: 90),
    DayScore(day: 'T', value: 79),
    DayScore(day: 'W'),
    DayScore(day: 'T', value: 76),
    DayScore(day: 'F'),
    DayScore(day: 'S', value: 76),
    DayScore(day: 'S'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        _Header(),
        const SizedBox(height: 24),
        SectionCard(
          child: Row(
            children: [
              const ScoreRing(score: 80, label: 'Posture'),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POSTURE SCORE',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Strong',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Across 14 sets logged',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Weekly Goal',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    '4/4',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: 1,
                  minHeight: 10,
                  backgroundColor: AppColors.track,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '0 sessions to go this week',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This Week',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Daily posture average',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              const WeeklyBarChart(data: _weekData),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text(
                'Training Plan',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Week ${UserSession.plan.weekIndexFor(DateTime.now()) + 1} of ${WorkoutPlan.totalWeeks}',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Tap a day to see that session',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: PlanCalendar(plan: UserSession.plan),
        ),
        const SizedBox(height: 24),
        const Text(
          'Quick Start',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Jump into a guided session',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),
        SectionCard(
          onTap: () {},
          child: Row(
            children: [
              const IconBadge(customIcon: AppLogo()),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Full Body Check',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Squat · Row · Plank',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatefulWidget {
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    try {
      final unread = await ApiClient.instance.fetchUnreadCount();
      if (!mounted) return;
      setState(() => _unread = unread);
    } catch (_) {
      // Badge chỉ là phụ trợ — hỏng mạng thì im lặng bỏ qua, đừng chặn Home.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    // Lấy lại số chưa đọc dù màn kia báo có đổi hay không: người dùng có thể
    // đã kéo-làm-mới và nhận thêm thông báo mới trong lúc ở đó.
    if (mounted) await _loadUnread();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                UserSession.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _openNotifications,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Badge(
                isLabelVisible: _unread > 0,
                backgroundColor: AppColors.primary,
                textColor: AppColors.onPrimary,
                label: Text('$_unread'),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
