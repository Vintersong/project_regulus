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

/// Top-right, under the text list: one chip per running drop effect (and the
/// shield), each an icon over a bar that drains as the effect runs out.
class EffectStrip extends PositionComponent {
  EffectStrip(this.session)
      : super(
          position: Vector2(
            GameConfig.playfieldLeft + GameConfig.playfieldWidth,
            38,
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
    // (effect, fraction of its time left); the shield has no timer.
    final chips = <(DropEffect, double)>[
      if (session.shield) (DropEffect.shield, 1.0),
      for (final e in session.dropEffects.running)
        (e.key, (e.value / e.key.seconds).clamp(0.0, 1.0)),
    ];

    var x = 0.0;
    for (final (effect, left) in chips) {
      x -= _chip;
      final color = effect.good ? Palette.good : Palette.bad;
      // Flash in the last second so it reads as running out.
      final blink = effect.seconds > 0 &&
          left * effect.seconds < 1 &&
          (left * effect.seconds * 8).floor().isEven;
      final rect = Rect.fromLTWH(x, 0, _chip, _chip);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rr, _bg);
      canvas.drawRRect(rr, _ring..color = color.withValues(alpha: blink ? 0.3 : 1));
      paintDropIcon(
        canvas,
        effect,
        rect.center.translate(0, -3),
        _chip * 0.5,
        color.withValues(alpha: blink ? 0.3 : 1),
      );
      if (effect.seconds > 0) {
        canvas.drawRect(
          Rect.fromLTWH(x + 6, _chip - 8, (_chip - 12) * left, 3),
          _bar..color = color,
        );
      }
      x -= _gap;
    }
  }
}
