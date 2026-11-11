import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Circular zoom lens showing the photo pixels around [imagePoint] so a
/// corner handle can be placed on an anchor's centre with single-pixel accuracy.
class MagnifierLoupe extends StatelessWidget {
  const MagnifierLoupe({
    super.key,
    required this.image,
    required this.imagePoint,
    required this.displayScale,
    this.diameter = 132,
    this.label,
  });

  final ui.Image image;

  /// Point under the corner handle, in image pixels.
  final Offset imagePoint;

  /// Logical pixels per image pixel on the calibration canvas.
  final double displayScale;
  final double diameter;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: diameter,
        child: CustomPaint(
          painter: _LoupePainter(
            image: image,
            imagePoint: imagePoint,
            // At least 4x the canvas magnification, and at least 3 logical
            // pixels per photo pixel, so individual pixels are visible.
            pixelsPerImagePixel: math.max(displayScale * 4, 3.0).clamp(0.5, 10.0),
            label: label,
            ringColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _LoupePainter extends CustomPainter {
  _LoupePainter({
    required this.image,
    required this.imagePoint,
    required this.pixelsPerImagePixel,
    required this.ringColor,
    this.label,
  });

  final ui.Image image;
  final Offset imagePoint;
  final double pixelsPerImagePixel;
  final Color ringColor;
  final String? label;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final circle = Rect.fromCircle(center: center, radius: radius);
    final srcSide = size.shortestSide / pixelsPerImagePixel;
    final src = Rect.fromCenter(center: imagePoint, width: srcSide, height: srcSide);

    canvas
      ..drawCircle(center + const Offset(0, 3), radius, Paint()..color = Colors.black38)
      ..save()
      ..clipPath(Path()..addOval(circle))
      ..drawRect(circle, Paint()..color = const Color(0xFF202020))
      ..drawImageRect(
        image,
        src,
        circle,
        Paint()
          ..filterQuality =
              pixelsPerImagePixel >= 3 ? FilterQuality.none : FilterQuality.medium,
      );

    // Crosshair marking the exact handle position (pixel centre).
    final cross = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 1;
    const gap = 5.0;
    canvas
      ..drawLine(Offset(circle.left, center.dy), Offset(center.dx - gap, center.dy), cross)
      ..drawLine(Offset(center.dx + gap, center.dy), Offset(circle.right, center.dy), cross)
      ..drawLine(Offset(center.dx, circle.top), Offset(center.dx, center.dy - gap), cross)
      ..drawLine(Offset(center.dx, center.dy + gap), Offset(center.dx, circle.bottom), cross)
      ..drawCircle(center, 1.2, Paint()..color = Colors.redAccent)
      ..restore()
      ..drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = ringColor,
      );

    final text = label;
    if (text != null) {
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      )..layout();
      final chip = Rect.fromCenter(
        center: Offset(center.dx, circle.bottom - 14),
        width: tp.width + 10,
        height: tp.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(chip, const Radius.circular(8)),
        Paint()..color = ringColor,
      );
      tp
        ..paint(canvas, chip.topLeft + const Offset(5, 2))
        ..dispose();
    }
  }

  @override
  bool shouldRepaint(_LoupePainter old) =>
      old.image != image ||
      old.imagePoint != imagePoint ||
      old.pixelsPerImagePixel != pixelsPerImagePixel ||
      old.label != label ||
      old.ringColor != ringColor;
}
