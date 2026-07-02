import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_rings.dart';

class HomeScreen extends StatelessWidget {
  final void Function(String exerciseName) onOpenCamera;
  final VoidCallback onOpenWorkout;
  final VoidCallback onOpenProfile;

  const HomeScreen({
    super.key,
    required this.onOpenCamera,
    required this.onOpenWorkout,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thứ ba, 1 tháng 7',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  SizedBox(height: 2),
                  Text('Tổng quan',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              GestureDetector(
                onTap: onOpenProfile,
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.border,
                  child: Icon(Icons.person, size: 16, color: AppColors.gray),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vòng tập luyện',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const ActivityRings(
                      size: 120,
                      rings: [
                        RingData(
                            background: AppColors.coralDark,
                            foreground: AppColors.coral,
                            progress: 0.6),
                        RingData(
                            background: AppColors.tealDark,
                            foreground: AppColors.teal,
                            progress: 0.88),
                        RingData(
                            background: AppColors.amberDark,
                            foreground: AppColors.amber,
                            progress: 0.714),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _RingLegendRow(
                              value: '24/40',
                              label: 'rep hôm nay',
                              color: AppColors.coralLight),
                          SizedBox(height: 8),
                          _RingLegendRow(
                              value: '88%',
                              label: 'tư thế đúng',
                              color: AppColors.teal),
                          SizedBox(height: 8),
                          _RingLegendRow(
                              value: '5/7',
                              label: 'ngày chuỗi tập',
                              color: AppColors.amber),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                  child: _StatCard(
                      label: 'Thời gian tập', value: '18', unit: 'phút')),
              SizedBox(width: 10),
              Expanded(
                  child: _StatCard(
                      label: 'Lỗi được sửa', value: '3', unit: 'lần')),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onOpenWorkout,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gợi ý set hôm nay',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.tealDark,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('~15 phút',
                            style: TextStyle(
                                color: AppColors.tealLight, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.swap_vert,
                            color: AppColors.coralLight, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ngực và tay',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(height: 2),
                            Text('Push-up · Hít đẩy vai · 6 hiệp',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textMuted, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingLegendRow extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _RingLegendRow({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12),
        children: [
          TextSpan(
              text: '$value ',
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          TextSpan(
              text: label,
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                    text: value,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600)),
                TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
