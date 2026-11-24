import 'dart:math';
import 'dart:ui';

import '../grid/drops.dart';
import '../grid/powerups.dart';

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

/// A [Path] built in icon space: (-1..1, -1..1) around [c], scaled by [u].
class _IconPath {
  _IconPath(this.c, this.u);
  final Offset c;
  final double u;
  final Path path = Path();

  double _x(double v) => c.dx + v * u;
  double _y(double v) => c.dy + v * u;

  _IconPath move(double x, double y) {
    path.moveTo(_x(x), _y(y));
    return this;
  }

  _IconPath line(double x, double y) {
    path.lineTo(_x(x), _y(y));
    return this;
  }

  _IconPath quad(double cx, double cy, double x, double y) {
    path.quadraticBezierTo(_x(cx), _y(cy), _x(x), _y(y));
    return this;
  }

  _IconPath cubic(double x1, double y1, double x2, double y2, double x, double y) {
    path.cubicTo(_x(x1), _y(y1), _x(x2), _y(y2), _x(x), _y(y));
    return this;
  }

  Path close() => path..close();
}

/// Vector icons for the four elements, same rules as [paintDropIcon]: a
/// square of side [size] centred on [c], one [color]. Fire is a flame, water
/// a droplet, air three gusts, earth a pair of peaks.
void paintElementIcon(
  Canvas canvas,
  ElementType element,
  Offset c,
  double size,
  Color color,
) {
  final u = size / 2;
  final fill = Paint()..color = color;
  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.8, size * 0.12)
    ..strokeCap = StrokeCap.round;
  _IconPath b() => _IconPath(c, u);

  switch (element) {
    case ElementType.fire:
      canvas.drawPath(
        b()
            .move(0, -1)
            .cubic(0.15, -0.5, 0.8, -0.2, 0.7, 0.3)
            .cubic(0.6, 0.8, 0.25, 1, 0, 1)
            .cubic(-0.3, 1, -0.7, 0.7, -0.7, 0.25)
            .cubic(-0.7, -0.1, -0.4, -0.3, -0.35, -0.6)
            .cubic(-0.1, -0.5, -0.05, -0.8, 0, -1)
            .close(),
        fill,
      );

    case ElementType.water:
      canvas.drawPath(
        b()
            .move(0, -1)
            .cubic(0.2, -0.6, 0.75, 0, 0.75, 0.35)
            .cubic(0.75, 0.75, 0.4, 1, 0, 1)
            .cubic(-0.4, 1, -0.75, 0.75, -0.75, 0.35)
            .cubic(-0.75, 0, -0.2, -0.6, 0, -1)
            .close(),
        fill,
      );

    case ElementType.air:
      // Three gusts, each a gentle S.
      for (final y in const [-0.55, 0.0, 0.55]) {
        canvas.drawPath(
          (b()
                ..move(-0.9, y)
                ..quad(-0.45, y - 0.4, 0, y)
                ..quad(0.45, y + 0.4, 0.9, y))
              .path,
          stroke,
        );
      }

    case ElementType.earth:
      // A tall peak with a shorter one beside it.
      canvas.drawPath(
        b().move(-0.95, 0.8).line(-0.1, -0.85).line(0.75, 0.8).close(),
        fill,
      );
      canvas.drawPath(
        b().move(0.15, 0.8).line(0.6, -0.1).line(1, 0.8).close(),
        fill,
      );
  }
}
