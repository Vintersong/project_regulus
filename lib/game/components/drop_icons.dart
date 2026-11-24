import 'dart:math';
import 'dart:ui';

import '../grid/drops.dart';

/// Vector icons for the mystery-drop effects, drawn straight onto a canvas so
/// no icon font or image assets are needed. Every icon fits a square of side
/// [size] centred on [c] and is drawn in a single [color].
///
/// Buried drops still show a "?" (the answer is the surprise); these appear
/// once an effect has been collected: in the pickup popup and the HUD strip.
void paintDropIcon(
  Canvas canvas,
  DropEffect effect,
  Offset c,
  double size,
  Color color,
) {
  final u = size / 2; // unit: the icon's half-width
  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.5, size * 0.11)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final fill = Paint()..color = color;

  // Local helper: a point in icon space (-1..1 on both axes).
  Offset p(double x, double y) => Offset(c.dx + x * u, c.dy + y * u);

  switch (effect) {
    case DropEffect.timeStop:
      // A clock face: ring plus hands.
      canvas.drawCircle(c, u * 0.9, stroke);
      canvas.drawLine(c, p(0, -0.55), stroke);
      canvas.drawLine(c, p(0.4, 0.2), stroke);

    case DropEffect.slow:
      // A snowflake: three crossing spokes.
      for (var i = 0; i < 3; i++) {
        final a = i * pi / 3;
        final d = Offset(cos(a), sin(a)) * u * 0.9;
        canvas.drawLine(c - d, c + d, stroke);
      }

    case DropEffect.shield:
      final path = Path()
        ..moveTo(c.dx, c.dy - u * 0.95)
        ..lineTo(c.dx + u * 0.8, c.dy - u * 0.55)
        ..quadraticBezierTo(
            c.dx + u * 0.8, c.dy + u * 0.5, c.dx, c.dy + u * 0.95)
        ..quadraticBezierTo(
            c.dx - u * 0.8, c.dy + u * 0.5, c.dx - u * 0.8, c.dy - u * 0.55)
        ..close();
      canvas.drawPath(path, fill);

    case DropEffect.extraLife:
      canvas.drawPath(heartPath(c, size * 0.95), fill);

    case DropEffect.jackpot:
      // A coin: ring with a bar down the middle.
      canvas.drawCircle(c, u * 0.9, stroke);
      canvas.drawLine(p(0, -0.45), p(0, 0.45), stroke);

    case DropEffect.bomb:
      canvas.drawCircle(p(-0.1, 0.2), u * 0.65, fill);
      canvas.drawLine(p(0.25, -0.25), p(0.6, -0.6), stroke);
      // The spark on the fuse.
      for (var i = 0; i < 4; i++) {
        final a = i * pi / 2 + pi / 4;
        canvas.drawLine(
          p(0.75, -0.75) + Offset(cos(a), sin(a)) * u * 0.1,
          p(0.75, -0.75) + Offset(cos(a), sin(a)) * u * 0.32,
          stroke..strokeWidth = max(1.2, size * 0.07),
        );
      }

    case DropEffect.rush:
      // A lightning bolt.
      final path = Path()
        ..moveTo(c.dx + u * 0.2, c.dy - u)
        ..lineTo(c.dx - u * 0.6, c.dy + u * 0.1)
        ..lineTo(c.dx - u * 0.05, c.dy + u * 0.1)
        ..lineTo(c.dx - u * 0.2, c.dy + u)
        ..lineTo(c.dx + u * 0.6, c.dy - u * 0.2)
        ..lineTo(c.dx + u * 0.05, c.dy - u * 0.2)
        ..close();
      canvas.drawPath(path, fill);

    case DropEffect.sluggish:
      // A down arrow onto a floor: heavy, pinned.
      canvas.drawLine(p(0, -0.85), p(0, 0.35), stroke);
      canvas.drawLine(p(-0.5, -0.1), p(0, 0.4), stroke);
      canvas.drawLine(p(0.5, -0.1), p(0, 0.4), stroke);
      canvas.drawLine(p(-0.7, 0.85), p(0.7, 0.85), stroke);

    case DropEffect.reinforcements:
      // Two diamonds: more of them coming.
      for (final dx in const [-0.42, 0.42]) {
        final path = Path()
          ..moveTo(c.dx + dx * u, c.dy - u * 0.55)
          ..lineTo(c.dx + (dx + 0.4) * u, c.dy)
          ..lineTo(c.dx + dx * u, c.dy + u * 0.55)
          ..lineTo(c.dx + (dx - 0.4) * u, c.dy)
          ..close();
        canvas.drawPath(path, fill);
      }
  }
}

/// A heart outline of width [w] centred on [c]; shared with the lives display.
Path heartPath(Offset c, double w) {
  final h = w * 0.9;
  final x = c.dx;
  final y = c.dy;
  return Path()
    ..moveTo(x, y + h * 0.45)
    ..cubicTo(x - w * 0.75, y - h * 0.05, x - w * 0.4, y - h * 0.6, x, y - h * 0.2)
    ..cubicTo(x + w * 0.4, y - h * 0.6, x + w * 0.75, y - h * 0.05, x, y + h * 0.45)
    ..close();
}
