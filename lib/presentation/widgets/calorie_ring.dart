import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_colors.dart';

class CalorieRing extends StatelessWidget {
  final int consumed;
  final int target;
  final double size;

  const CalorieRing({
    super.key,
    required this.consumed,
    required this.target,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.5) : 0.0;
    final remaining = (target - consumed).clamp(0, target);
    final isOver = consumed > target;
    final percentage = target > 0 ? ((consumed / target) * 100).round() : 0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle glow behind the ring
          Container(
            width: size * 0.7,
            height: size * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isOver ? AppColors.error : AppColors.accentGreen)
                      .withValues(alpha: 0.15),
                  blurRadius: size * 0.3,
                  spreadRadius: size * 0.05,
                ),
              ],
            ),
          ),
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress,
              isOver: isOver,
              ringBgColor: C.of(context).text,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$consumed',
                style: TextStyle(
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.w800,
                  color: isOver ? AppColors.error : C.of(context).text,
                  letterSpacing: -1,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'of $target kcal',
                style: TextStyle(
                  fontSize: size * 0.065,
                  color: C.of(context).text54,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: (isOver ? AppColors.error : AppColors.accentGreen)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOver
                      ? '${consumed - target} over'
                      : '$remaining left ($percentage%)',
                  style: TextStyle(
                    fontSize: size * 0.055,
                    color: isOver ? AppColors.error : AppColors.accentGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().scale(
          duration: 800.ms,
          curve: Curves.elasticOut,
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.0, 1.0),
        );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isOver;
  final Color ringBgColor;

  _RingPainter({required this.progress, required this.isOver, required this.ringBgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const strokeWidth = 14.0;

    // Background ring
    final bgPaint = Paint()
      ..color = ringBgColor.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring with gradient
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -pi / 2,
          endAngle: 3 * pi / 2,
          colors: isOver
              ? [AppColors.warning, AppColors.error]
              : [
                  AppColors.accentGreen.withValues(alpha: 0.5),
                  AppColors.accentGreen,
                ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      final sweepAngle = 2 * pi * clampedProgress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );

      // Glow effect on the progress tip
      final tipAngle = -pi / 2 + sweepAngle;
      final tipX = center.dx + radius * cos(tipAngle);
      final tipY = center.dy + radius * sin(tipAngle);
      final glowPaint = Paint()
        ..color = (isOver ? AppColors.error : AppColors.accentGreen)
            .withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(tipX, tipY), strokeWidth / 2, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.isOver != isOver;
}
