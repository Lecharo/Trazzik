import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';

/// Shared 2D CAD symbol drawing primitives used across interactive and export painters.
class CadSymbolDrawer {
  const CadSymbolDrawer._();

  /// Converts a [Polygon2D] in meter coordinates into a scaled [Path].
  static Path polygonToPath(Polygon2D polygon, double scale) {
    final path = Path();
    if (polygon.vertices.isEmpty) return path;

    final first = polygon.vertices.first;
    path.moveTo(first.x * scale, first.y * scale);

    for (int i = 1; i < polygon.vertices.length; i++) {
      final pt = polygon.vertices[i];
      path.lineTo(pt.x * scale, pt.y * scale);
    }
    path.close();
    return path;
  }

  /// Converts a [Polygon2D] into a [Path] using a custom coordinate transform.
  static Path polygonToPathTransformed(
    Polygon2D polygon,
    Offset Function(double x, double y) toCanvas,
  ) {
    final path = Path();
    if (polygon.vertices.isEmpty) return path;

    final first = toCanvas(polygon.vertices.first.x, polygon.vertices.first.y);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < polygon.vertices.length; i++) {
      final pt = toCanvas(polygon.vertices[i].x, polygon.vertices[i].y);
      path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    return path;
  }

  static void drawSwingDoor(
    Canvas canvas,
    double left,
    double top,
    double w,
    double h,
    double scale,
    Color strokeColor, {
    bool flipX = false,
    bool flipY = false,
    Color? arcColor,
  }) {
    final isHorizontal = w >= h;
    final arcPaint = Paint()
      ..color = arcColor ?? strokeColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final leafPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, 0.04 * scale);

    final jambPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    if (isHorizontal) {
      final jambW = math.min(w * 0.10, math.max(2.5, 0.06 * scale));
      canvas.drawRect(Rect.fromLTWH(left, top, jambW, h), jambPaint);
      canvas.drawRect(Rect.fromLTWH(left + w - jambW, top, jambW, h), jambPaint);

      final hingeX = flipX ? (left + w - jambW) : (left + jambW);
      final hingeY = flipY ? top : (top + h);
      final doorLength = w - 2 * jambW;
      final targetY = flipY ? (hingeY + doorLength) : (hingeY - doorLength);

      canvas.drawLine(
        Offset(hingeX, hingeY),
        Offset(hingeX, targetY),
        leafPaint,
      );

      final arcRect = Rect.fromCircle(
        center: Offset(hingeX, hingeY),
        radius: doorLength,
      );

      double startAngle;
      double sweepAngle;
      if (!flipY) {
        if (!flipX) {
          startAngle = 0.0;
          sweepAngle = -math.pi / 2;
        } else {
          startAngle = -math.pi;
          sweepAngle = math.pi / 2;
        }
      } else {
        if (!flipX) {
          startAngle = 0.0;
          sweepAngle = math.pi / 2;
        } else {
          startAngle = math.pi;
          sweepAngle = -math.pi / 2;
        }
      }

      canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);
    } else {
      final jambH = math.min(h * 0.10, math.max(2.5, 0.06 * scale));
      canvas.drawRect(Rect.fromLTWH(left, top, w, jambH), jambPaint);
      canvas.drawRect(Rect.fromLTWH(left, top + h - jambH, w, jambH), jambPaint);

      final hingeX = flipX ? left : (left + w);
      final hingeY = flipY ? (top + h - jambH) : (top + jambH);
      final doorLength = h - 2 * jambH;
      final targetX = flipX ? (hingeX + doorLength) : (hingeX - doorLength);

      canvas.drawLine(
        Offset(hingeX, hingeY),
        Offset(targetX, hingeY),
        leafPaint,
      );

      final arcRect = Rect.fromCircle(
        center: Offset(hingeX, hingeY),
        radius: doorLength,
      );

      double startAngle;
      double sweepAngle;
      if (!flipX) {
        if (!flipY) {
          startAngle = math.pi / 2;
          sweepAngle = math.pi / 2;
        } else {
          startAngle = -math.pi / 2;
          sweepAngle = -math.pi / 2;
        }
      } else {
        if (!flipY) {
          startAngle = math.pi / 2;
          sweepAngle = -math.pi / 2;
        } else {
          startAngle = -math.pi / 2;
          sweepAngle = math.pi / 2;
        }
      }

      canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);
    }
  }

  static void drawSlidingDoor(
    Canvas canvas,
    double left,
    double top,
    double w,
    double h,
    double scale,
    Color strokeColor,
  ) {
    final isHorizontal = w >= h;
    final glassPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, 0.03 * scale);

    final trackPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    if (isHorizontal) {
      final midY = top + h / 2;
      final offsetTrack = math.max(2.0, h * 0.22);
      canvas.drawLine(
        Offset(left, midY - offsetTrack),
        Offset(left + w * 0.55, midY - offsetTrack),
        glassPaint,
      );
      canvas.drawLine(
        Offset(left + w * 0.45, midY + offsetTrack),
        Offset(left + w, midY + offsetTrack),
        glassPaint,
      );
      canvas.drawLine(Offset(left, midY), Offset(left + w, midY), trackPaint);
    } else {
      final midX = left + w / 2;
      final offsetTrack = math.max(2.0, w * 0.22);
      canvas.drawLine(
        Offset(midX - offsetTrack, top),
        Offset(midX - offsetTrack, top + h * 0.55),
        glassPaint,
      );
      canvas.drawLine(
        Offset(midX + offsetTrack, top + h * 0.45),
        Offset(midX + offsetTrack, top + h),
        glassPaint,
      );
      canvas.drawLine(Offset(midX, top), Offset(midX, top + h), trackPaint);
    }
  }

  static void drawWindow(
    Canvas canvas,
    double left,
    double top,
    double w,
    double h,
    double scale,
    Color strokeColor, {
    Color glassColor = const Color(0xFF80D8FF),
    bool drawOuterFrame = false,
  }) {
    final isHorizontal = w >= h;
    final glassPaint = Paint()
      ..color = glassColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, 0.025 * scale);

    final framePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    if (drawOuterFrame) {
      canvas.drawRect(
        Rect.fromLTWH(left, top, w, h),
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    if (isHorizontal) {
      final jambW = math.min(w * 0.08, math.max(2.5, 0.05 * scale));
      canvas.drawRect(Rect.fromLTWH(left, top, jambW, h), framePaint);
      canvas.drawRect(Rect.fromLTWH(left + w - jambW, top, jambW, h), framePaint);

      final glassY1 = top + h * 0.35;
      final glassY2 = top + h * 0.65;
      canvas.drawLine(
        Offset(left + jambW, glassY1),
        Offset(left + w - jambW, glassY1),
        glassPaint,
      );
      canvas.drawLine(
        Offset(left + jambW, glassY2),
        Offset(left + w - jambW, glassY2),
        glassPaint,
      );
    } else {
      final jambH = math.min(h * 0.08, math.max(2.5, 0.05 * scale));
      canvas.drawRect(Rect.fromLTWH(left, top, w, jambH), framePaint);
      canvas.drawRect(Rect.fromLTWH(left, top + h - jambH, w, jambH), framePaint);

      final glassX1 = left + w * 0.35;
      final glassX2 = left + w * 0.65;
      canvas.drawLine(
        Offset(glassX1, top + jambH),
        Offset(glassX1, top + h - jambH),
        glassPaint,
      );
      canvas.drawLine(
        Offset(glassX2, top + jambH),
        Offset(glassX2, top + h - jambH),
        glassPaint,
      );
    }
  }

  static void drawGate(
    Canvas canvas,
    double left,
    double top,
    double w,
    double h,
    double scale,
    Color strokeColor,
  ) {
    final isHorizontal = w >= h;
    final postPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;
    final dashPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (isHorizontal) {
      final postW = math.min(w * 0.12, 0.25 * scale);
      canvas.drawRect(Rect.fromLTWH(left, top, postW, h), postPaint);
      canvas.drawRect(Rect.fromLTWH(left + w - postW, top, postW, h), postPaint);

      canvas.drawLine(
        Offset(left + postW, top),
        Offset(left + w - postW, top + h),
        dashPaint,
      );
      canvas.drawLine(
        Offset(left + postW, top + h),
        Offset(left + w - postW, top),
        dashPaint,
      );
    } else {
      final postH = math.min(h * 0.12, 0.25 * scale);
      canvas.drawRect(Rect.fromLTWH(left, top, w, postH), postPaint);
      canvas.drawRect(Rect.fromLTWH(left, top + h - postH, w, postH), postPaint);

      canvas.drawLine(
        Offset(left, top + postH),
        Offset(left + w, top + h - postH),
        dashPaint,
      );
      canvas.drawLine(
        Offset(left + w, top + postH),
        Offset(left, top + h - postH),
        dashPaint,
      );
    }
  }

  static void drawStairs(
    Canvas canvas,
    double left,
    double top,
    double w,
    double h,
    double scale,
    Color strokeColor, {
    bool flipX = false,
    bool flipY = false,
    Color? backgroundColor,
    Color? arrowColor,
  }) {
    if (backgroundColor != null) {
      canvas.drawRect(
        Rect.fromLTWH(left, top, w, h),
        Paint()..color = backgroundColor,
      );
      canvas.drawRect(
        Rect.fromLTWH(left, top, w, h),
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    final isHorizontal = w >= h;
    final stepPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final effectiveArrowColor = arrowColor ?? strokeColor;
    final arrowPaint = Paint()
      ..color = effectiveArrowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    const stepSizeMeters = 0.28;
    final stepPx = math.max(1.0, stepSizeMeters * scale);

    if (isHorizontal) {
      final stepCount = math.max(4, (w / stepPx).round());
      final dx = w / stepCount;
      for (int i = 1; i < stepCount; i++) {
        canvas.drawLine(
          Offset(left + i * dx, top),
          Offset(left + i * dx, top + h),
          stepPaint,
        );
      }

      final midY = top + h / 2;
      if (!flipX) {
        canvas.drawCircle(
          Offset(left + 8, midY),
          3.0,
          Paint()..color = effectiveArrowColor,
        );
        canvas.drawLine(
          Offset(left + 8, midY),
          Offset(left + w - 12, midY),
          arrowPaint,
        );
        final arrowPath = Path()
          ..moveTo(left + w - 18, midY - 5)
          ..lineTo(left + w - 10, midY)
          ..lineTo(left + w - 18, midY + 5);
        canvas.drawPath(arrowPath, arrowPaint);
      } else {
        canvas.drawCircle(
          Offset(left + w - 8, midY),
          3.0,
          Paint()..color = effectiveArrowColor,
        );
        canvas.drawLine(
          Offset(left + w - 8, midY),
          Offset(left + 12, midY),
          arrowPaint,
        );
        final arrowPath = Path()
          ..moveTo(left + 18, midY - 5)
          ..lineTo(left + 10, midY)
          ..lineTo(left + 18, midY + 5);
        canvas.drawPath(arrowPath, arrowPaint);
      }
    } else {
      final stepCount = math.max(4, (h / stepPx).round());
      final dy = h / stepCount;
      for (int i = 1; i < stepCount; i++) {
        canvas.drawLine(
          Offset(left, top + i * dy),
          Offset(left + w, top + i * dy),
          stepPaint,
        );
      }

      final midX = left + w / 2;
      // Default vertical stairs ascend from top (front) toward bottom (rear) when !flipY.
      if (!flipY) {
        canvas.drawCircle(
          Offset(midX, top + 8),
          3.0,
          Paint()..color = effectiveArrowColor,
        );
        canvas.drawLine(
          Offset(midX, top + 8),
          Offset(midX, top + h - 12),
          arrowPaint,
        );
        final arrowPath = Path()
          ..moveTo(midX - 5, top + h - 18)
          ..lineTo(midX, top + h - 10)
          ..lineTo(midX + 5, top + h - 18);
        canvas.drawPath(arrowPath, arrowPaint);
      } else {
        canvas.drawCircle(
          Offset(midX, top + h - 8),
          3.0,
          Paint()..color = effectiveArrowColor,
        );
        canvas.drawLine(
          Offset(midX, top + h - 8),
          Offset(midX, top + 12),
          arrowPaint,
        );
        final arrowPath = Path()
          ..moveTo(midX - 5, top + 18)
          ..lineTo(midX, top + 10)
          ..lineTo(midX + 5, top + 18);
        canvas.drawPath(arrowPath, arrowPaint);
      }
    }
  }

  /// Draws a North compass rose with the 'N' label anchored along the rotated North vector.
  static void drawNorthCompass(
    Canvas canvas,
    Offset center,
    double radius,
    double orientationDegrees, {
    Color? backgroundColor,
    Color ringColor = const Color(0x6600E5FF),
    Color northColor = const Color(0xFFEF5350),
    Color southColor = const Color(0xFF90A4AE),
    Color labelColor = const Color(0xFF00E5FF),
  }) {
    if (backgroundColor != null) {
      canvas.drawCircle(center, radius, Paint()..color = backgroundColor);
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final radians = (orientationDegrees - 90) * math.pi / 180.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(radians);

    final northPath = Path()
      ..moveTo(radius - 5, 0)
      ..lineTo(0, -4)
      ..lineTo(0, 4)
      ..close();
    canvas.drawPath(
      northPath,
      Paint()
        ..color = northColor
        ..style = PaintingStyle.fill,
    );

    final southPath = Path()
      ..moveTo(-radius + 5, 0)
      ..lineTo(0, -4)
      ..lineTo(0, 4)
      ..close();
    canvas.drawPath(
      southPath,
      Paint()
        ..color = southColor
        ..style = PaintingStyle.fill,
    );

    canvas.restore();

    final labelCenter = Offset(
      center.dx + (radius + 8) * math.cos(radians),
      center.dy + (radius + 8) * math.sin(radians),
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        labelCenter.dx - textPainter.width / 2,
        labelCenter.dy - textPainter.height / 2,
      ),
    );
  }
}
