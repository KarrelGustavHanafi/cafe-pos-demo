import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A lightweight bar chart widget using CustomPainter.
/// No external dependencies — compatible with the existing Flutter project.
class SalesBarChart extends StatelessWidget {
  final List<SalesBarData> data;
  final double height;

  const SalesBarChart({
    super.key,
    required this.data,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('Belum ada data.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: _BarChartPainter(data: data),
          );
        },
      ),
    );
  }
}

class SalesBarData {
  final String label;
  final int value;
  final bool isHighlighted;

  const SalesBarData({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });
}

class _BarChartPainter extends CustomPainter {
  final List<SalesBarData> data;

  _BarChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxValue = data.map((d) => d.value).reduce(math.max);
    if (maxValue == 0) return;

    final barCount = data.length;
    final totalPadding = (barCount + 1) * 4.0;
    final barWidth = (size.width - totalPadding) / barCount;
    final chartHeight = size.height - 20; // leave 20px for labels

    final normalPaint = Paint()
      ..color = AppColors.primaryBorder
      ..style = PaintingStyle.fill;

    final highlightPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    const textStyle = TextStyle(
      color: AppColors.textMuted,
      fontSize: 9,
      fontWeight: FontWeight.w700,
    );

    for (int i = 0; i < barCount; i++) {
      final item = data[i];
      final ratio = item.value / maxValue;
      final barH = (chartHeight * ratio).clamp(3.0, chartHeight);
      final x = 4.0 + i * (barWidth + 4);
      final y = chartHeight - barH;

      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barH),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );

      canvas.drawRRect(rrect, item.isHighlighted ? highlightPaint : normalPaint);

      // Draw label
      final tp = TextPainter(
        text: TextSpan(text: item.label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: barWidth + 4);

      tp.paint(
        canvas,
        Offset(x + (barWidth - tp.width) / 2, chartHeight + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
