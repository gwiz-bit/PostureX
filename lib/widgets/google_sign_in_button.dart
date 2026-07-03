import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// "Continue with Google" button — dark outlined style (Google's
/// recommended button treatment for dark surfaces).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed, this.label = 'Continue with Google'});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _GoogleLogo(),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal four-color "G" mark approximating the Google logo without
/// relying on a bundled/network image asset.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeWidth = size.width * 0.22;
    final radius = (size.width - strokeWidth) / 2;
    final center = rect.center;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    void arc(double startDeg, double sweepDeg, Color color) {
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startDeg * 3.1415926535 / 180,
        sweepDeg * 3.1415926535 / 180,
        false,
        paint,
      );
    }

    arc(-45, 90, const Color(0xFF4285F4));
    arc(45, 90, const Color(0xFF34A853));
    arc(135, 90, const Color(0xFFFBBC05));
    arc(225, 90, const Color(0xFFEA4335));

    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - strokeWidth / 2, size.width / 2 - strokeWidth * 0.35, strokeWidth),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
