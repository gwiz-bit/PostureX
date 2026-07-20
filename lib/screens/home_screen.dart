import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/workout_stats.dart';
import '../widgets/app_logo.dart';
import 'notifications_screen.dart';
import '../widgets/icon_badge.dart';
import '../widgets/plan_calendar.dart';
import '../widgets/score_ring.dart';
import '../widgets/section_card.dart';
import '../widgets/weekly_bar_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Workout> _workouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Public so [MainShell] can force a fresh fetch when this tab is
  /// selected — matches [ProgressScreenState.reload]/[ProfileScreenState.reload].
  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final workouts = await ApiClient.instance.fetchWorkouts();
      if (!mounted) return;
      setState(() {
        _workouts = workouts;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load your workout data.';
        _isLoading = false;
      });
    }
  }

  /// Same Mon..Sun bucketing as [ProgressScreenState._weeklyTrend] — one
  /// average accuracy score per day this week, `null` for days with no
  /// logged session.
  List<DayScore> _weeklyTrend() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    return List.generate(7, (i) {
      final day = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i);
      final dayScores = [
        for (final w in _workouts)
          if (w.accuracyScore != null &&
              w.startedAt.year == day.year &&
              w.startedAt.month == day.month &&
              w.startedAt.day == day.day)
            w.accuracyScore!,
      ];
      final value = dayScores.isEmpty
          ? null
          : (dayScores.reduce((a, b) => a + b) / dayScores.length).round();
      return DayScore(day: labels[i], value: value);
    });
  }

  int _sessionsThisWeek() {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return _workouts.where((w) => !w.startedAt.isBefore(startOfWeek)).length;
  }

  String _postureLabel(int score, bool hasData) {
    if (!hasData) return 'No data';
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Strong';
    if (score >= 50) return 'Fair';
    return 'Needs work';
  }

  @override
  Widget build(BuildContext context) {
    final stats = computeStats(_workouts);
    final hasScoreData = stats.averageAccuracy != null;
    final overallScore = stats.averageAccuracy?.round() ?? 0;
    final weeklyGoal = UserSession.weeklyGoal;
    final completedThisWeek = _sessionsThisWeek();
    final goalProgress = weeklyGoal <= 0 ? 0.0 : (completedThisWeek / weeklyGoal).clamp(0.0, 1.0);
    final remaining = (weeklyGoal - completedThisWeek).clamp(0, weeklyGoal);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          _Header(),
          const SizedBox(height: 24),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_errorMessage != null)
            SectionCard(
              child: Column(
                children: [
                  Text(_errorMessage!, style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          else ...[
            SectionCard(
              child: Row(
                children: [
                  ScoreRing(score: overallScore, label: 'Posture'),
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
                        Text(
                          _postureLabel(overallScore, hasScoreData),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stats.sessionCount == 0
                              ? 'No sets logged yet'
                              : 'Across ${stats.sessionCount} sets logged',
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
                      Text(
                        '$completedThisWeek/$weeklyGoal',
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
                      value: goalProgress,
                      minHeight: 10,
                      backgroundColor: AppColors.track,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    remaining <= 0
                        ? 'Goal reached this week!'
                        : '$remaining session${remaining == 1 ? '' : 's'} to go this week',
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
                  WeeklyBarChart(data: _weeklyTrend()),
                ],
              ),
            ),
          ],
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
            child: PlanCalendar(
              plan: UserSession.plan,
              onDayChanged: (updatedDay) {
                setState(() {
                  UserSession.plan = UserSession.plan.replacingDay(updatedDay);
                });
              },
            ),
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
      ),
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
