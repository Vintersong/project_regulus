import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';
import '../grid/drops.dart';
import '../grid/session.dart';
import '../palette.dart';
import 'drop_icons.dart';

/// Top-left: how much of the field is claimed, as a bar with a notch at the
/// level's target, and the lives left as hearts.
class ClaimBar extends PositionComponent {
  ClaimBar(this.session)
      : super(
          position: Vector2(GameConfig.playfieldLeft, 10),
          size: Vector2(360, 18),
          priority: 20,
        );

  final GameSession session;
  double _shown = 0; // eased, so a capture sweeps the bar rather than jumping
  double _time = 0;

  final Paint _track = Paint()..color = Palette.letterbox;
  final Paint _fill = Paint();
  final Paint _outline = Paint()
    ..color = Palette.line
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _notch = Paint()
    ..color = Palette.warn
    ..strokeWidth = 3;

  @override
  void update(double dt) {
    _time += dt;
    final target = session.grid.claimedFraction.clamp(0.0, 1.0);
    _shown += (target - _shown) * min(1.0, dt * 10);
  }

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(4),
    );
    canvas.drawRRect(r, _track);

    final reached = session.grid.targetReached;
    _fill.color = reached
        ? Palette.good.withValues(alpha: 0.75 + 0.25 * sin(_time * 6))
        : Palette.accent;
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x * _shown, size.y), _fill);
    canvas.restore();
    canvas.drawRRect(r, _outline);

    // The notch: how far you need to get.
    final nx = size.x * session.grid.captureTarget;
    canvas.drawLine(Offset(nx, -3), Offset(nx, size.y + 3), _notch);

    // Lives, as hearts after the bar; spent ones are hollow.
    final heart = Paint();
    for (var i = 0; i < GameConfig.maxLives; i++) {
      final alive = i < session.lives;
      heart
        ..color = alive ? Palette.bad : Palette.line.withValues(alpha: 0.3)
        ..style = alive ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(
        heartPath(Offset(size.x + 26 + i * 26, size.y / 2), 22),
        heart,
      );
    }
  }
}

/// Top-right: one chip per running element, drop effect and the shield, each
/// an icon over a bar that drains as it runs out.
class EffectStrip extends PositionComponent {
  EffectStrip(this.session)
      : super(
          position: Vector2(
            GameConfig.playfieldLeft + GameConfig.playfieldWidth,
            4,
          ),
          priority: 20,
        );

  final GameSession session;

  static const double _chip = 44;
  static const double _gap = 8;

  final Paint _bg = Paint()..color = Palette.letterbox.withValues(alpha: 0.85);
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _bar = Paint();

  @override
  void render(Canvas canvas) {
    final chips = <_Chip>[
      for (final e in session.effects.running)
        _Chip(
          Palette.forElement(e.key),
          (canvas, c, size, color) =>
              paintElementIcon(canvas, e.key, c, size, color),
          e.value / e.key.duration,
          e.value,
        ),
      if (session.shield)
        _Chip(
          Palette.good,
          (canvas, c, size, color) =>
              paintDropIcon(canvas, DropEffect.shield, c, size, color),
          1,
          0, // no timer
        ),
      for (final e in session.dropEffects.running)
        _Chip(
          e.key.good ? Palette.good : Palette.bad,
          (canvas, c, size, color) =>
              paintDropIcon(canvas, e.key, c, size, color),
          e.value / e.key.seconds,
          e.value,
        ),
    ];

    var x = 0.0;
    for (final chip in chips) {
      x -= _chip;
      // Flash in the last second so it reads as running out.
      final blink = chip.secondsLeft > 0 &&
          chip.secondsLeft < 1 &&
          (chip.secondsLeft * 8).floor().isEven;
      final color = chip.color.withValues(alpha: blink ? 0.3 : 1);
      final rect = Rect.fromLTWH(x, 0, _chip, _chip);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rr, _bg);
      canvas.drawRRect(rr, _ring..color = color);
      chip.paintIcon(canvas, rect.center.translate(0, -3), _chip * 0.5, color);
      if (chip.secondsLeft > 0) {
        canvas.drawRect(
          Rect.fromLTWH(
            x + 6,
            _chip - 8,
            (_chip - 12) * chip.left.clamp(0.0, 1.0),
            3,
          ),
          _bar..color = color,
        );
      }
      x -= _gap;
    }
  }
}

/// One thing to show in [EffectStrip]. [secondsLeft] of 0 means untimed.
class _Chip {
  _Chip(this.color, this.paintIcon, this.left, this.secondsLeft);

  final Color color;
  final void Function(Canvas canvas, Offset c, double size, Color color)
      paintIcon;

  /// Fraction of its time left, 0..1.
  final double left;
  final double secondsLeft;
}

/// A dark rounded panel drawn behind a [TextComponent] so the text stays
/// readable over any ground colour. It follows the text's size, and draws
/// nothing while the text is empty.
class TextPanel extends PositionComponent {
  TextPanel(this.target, {required int priority, double opacity = 0.88})
      : _fill = Paint()..color = Palette.letterbox.withValues(alpha: opacity),
        super(priority: priority);

  final TextComponent target;
  final Paint _fill;
  final Paint _edge = Paint()
    ..color = Palette.line.withValues(alpha: 0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  static const double _padX = 28;
  static const double _padY = 18;

  @override
  void render(Canvas canvas) {
    if (target.text.isEmpty) return;
    final topLeft = target.topLeftPosition;
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        topLeft.x - _padX,
        topLeft.y - _padY,
        target.size.x + _padX * 2,
        target.size.y + _padY * 2,
      ),
      const Radius.circular(14),
    );
    canvas.drawRRect(rr, _fill);
    canvas.drawRRect(rr, _edge);
  }
}
