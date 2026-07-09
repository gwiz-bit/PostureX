import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgressScreen extends StatelessWidget {
  final VoidCallback onOpenProfile;

  const ProgressScreen({super.key, required this.onOpenProfile});

  static const _dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _values = [0.4, 0.65, 0.9, 0.3, 0.55, 0.12, 0.12];
  static const _highlightIndex = 2;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tiến trình',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600)),
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
          const SizedBox(height: 14),
          const SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _LineChartPainter(
                values: _values,
                highlightIndex: _highlightIndex,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: _dayLabels
                .map((day) => Expanded(
                      child: Text(day,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 18),
          const Text('Lịch sử gần đây',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          const _HistoryRow(
              name: 'Squat',
              detail: 'Hôm nay, 24 rep',
              accuracy: '88% đúng',
              good: true),
          const _HistoryRow(
              name: 'Push-up',
              detail: 'Hôm qua, 45 rep',
              accuracy: '78% đúng',
              good: false),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final int highlightIndex;

  const _LineChartPainter(
      {required this.values, required this.highlightIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final n = values.length;
    final xStep = size.width / (n - 1);
    const vPad = 14.0; // keep dots from clipping at edges

    final points = List.generate(n, (i) {
      return Offset(
        i * xStep,
        vPad + (size.height - vPad * 2) * (1 - values[i]),
      );
    });

    // Filled gradient area below the line
    final fillPath = Path()
      ..moveTo(points.first.dx, size.height)
      ..lineTo(points.first.dx, points.first.dy);
    for (int i = 1; i < n; i++) {
      fillPath.lineTo(points[i].dx, points[i].dy);
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.coral.withValues(alpha: 0.35),
            AppColors.coral.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line connecting all points
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < n; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppColors.coral
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots at each data point
    for (int i = 0; i < n; i++) {
      final p = points[i];
      if (i == highlightIndex) {
        // Outer glow
        canvas.drawCircle(
            p, 9, Paint()..color = AppColors.coral.withValues(alpha: 0.2));
        // Filled dot
        canvas.drawCircle(p, 5, Paint()..color = AppColors.coral);
        // White center
        canvas.drawCircle(p, 2.5, Paint()..color = Colors.white);
      } else {
        // Background fill
        canvas.drawCircle(p, 3.5, Paint()..color = AppColors.coralDark);
        // Outline
        canvas.drawCircle(
          p,
          3.5,
          Paint()
            ..color = AppColors.coral
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.values != values || old.highlightIndex != highlightIndex;
}

class _HistoryRow extends StatelessWidget {
  final String name;
  final String detail;
  final String accuracy;
  final bool good;

  const _HistoryRow({
    required this.name,
    required this.detail,
    required this.accuracy,
    required this.good,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(detail,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: good ? AppColors.tealDark : AppColors.amberDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              accuracy,
              style: TextStyle(
                color: good ? AppColors.tealLight : AppColors.amberLight,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
