import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show FontWeight, TextStyle;

import '../config.dart';
import '../grid/drops.dart';
import '../grid/events.dart';
import 'drop_icons.dart';
import '../grid/powerups.dart';
import '../grid/session.dart';
import '../palette.dart';

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color,
      this.gravity)
      : maxLife = life;

  double x, y, vx, vy;
  double life;
  final double maxLife;
  final double size;
  final Color color;
  final double gravity;
}

class _Ring {
  _Ring(this.x, this.y, this.radius, this.duration, this.color, this.delay)
      : age = -delay;

  final double x, y, radius, duration, delay;
  final Color color;
  double age;
}

class _Popup {
  _Popup(this.x, this.y, this.text, this.color, this.size,
      {this.icon, this.element});

  /// Drawn above the text when set (a collected drop's effect).
  final DropEffect? icon;
  final ElementType? element;
  final double x, y;
  final String text;
  final Color color;
  final double size;
  double age = 0;
}

/// All the juice: sparks, shockwave rings, score popups and screen shake.
///
/// It owns no game rules. It drains what the session reports (captures,
/// deaths, kills, pickups, item use) and turns each into effects, plus a few
/// ambient ones (the cut's sparks, an aura while an element runs).
class VfxLayer extends PositionComponent {
  VfxLayer(this.session, {required this.onShake}) : super(priority: 15);

  final GameSession session;

  /// Receives the camera offset to apply this frame (zero when still).
  final void Function(Offset offset) onShake;

  final Random _rng = Random();
  final List<_Spark> _sparks = [];
  final List<_Ring> _rings = [];
  final List<_Popup> _popups = [];

  double _shake = 0;
  bool _wasShaking = false;
  double _ripple = 0;
  double _time = 0;

  /// A full-field colour flash when an element fires; fades out quickly.
  Color _flashColor = Palette.accent;
  double _flash = 0;

  /// Elements running last frame, to notice the moment one runs out.
  final Set<ElementType> _wasRunning = {};

  static const int _maxSparks = 1500;

  // Cell units -> world pixels.
  double _px(double column) =>
      GameConfig.playfieldLeft + column * GameConfig.cellSize;
  double _py(double row) => GameConfig.playfieldTop + row * GameConfig.cellSize;

  // --- spawning -----------------------------------------------------------

  void _spark(
    double x,
    double y,
    Color color, {
    double speed = 80,
    double life = 0.6,
    double size = 2.5,
    double gravity = 0,
    double angle = double.nan,
  }) {
    if (_sparks.length >= _maxSparks) return;
    final a = angle.isNaN ? _rng.nextDouble() * 2 * pi : angle;
    final v = speed * (0.4 + _rng.nextDouble() * 0.6);
    _sparks.add(
      _Spark(x, y, cos(a) * v, sin(a) * v, life * (0.6 + _rng.nextDouble() * 0.4),
          size, color, gravity),
    );
  }

  void _burst(
    double x,
    double y,
    Color color,
    int count, {
    double speed = 120,
    double life = 0.7,
    double size = 2.5,
    double gravity = 0,
  }) {
    for (var i = 0; i < count; i++) {
      _spark(x, y, color,
          speed: speed, life: life, size: size, gravity: gravity);
    }
  }

  void _ring(double x, double y, double radius, Color color,
      {double duration = 0.6, double delay = 0}) {
    _rings.add(_Ring(x, y, radius, duration, color, delay));
  }

  void _popup(double x, double y, String text, Color color, double size,
      {DropEffect? icon, ElementType? element}) {
    _popups.add(_Popup(x, y, text, color, size, icon: icon, element: element));
  }

  void _addShake(double amount) => _shake = min(1, max(_shake, amount));

  // --- reacting to the game ----------------------------------------------

  void _handle(GameEvent event) {
    switch (event) {
      case Captured(:final cells, :final points, :final combo, :final x, :final y):
        final cx = _px(x);
        final cy = _py(y);
        // A sparkle across the ground just won.
        final stride = max(1, cells.length ~/ 90);
        for (var i = 0; i < cells.length; i += stride) {
          final sx = _px(session.grid.columnOf(cells[i]) + 0.5);
          final sy = _py(session.grid.rowOf(cells[i]) + 0.5);
          _spark(sx, sy, i.isEven ? Palette.accent : Palette.line,
              speed: 30, life: 0.9, size: 2.2, gravity: -25);
        }
        _ring(cx, cy, min(280, 70 + sqrt(cells.length) * 3.2), Palette.accent,
            duration: 0.75);
        final label = combo > 1 ? '+$points  x$combo' : '+$points';
        _popup(cx, cy, label, combo > 1 ? Palette.fire : Palette.accent,
            20.0 + combo * 3);
        _addShake(min(0.45, cells.length / 5000));

      case CutStarted(:final x, :final y):
        // A warning ping where the cut begins: you have just left safety.
        _ring(_px(x), _py(y), 64, Palette.warn, duration: 0.4);
        _burst(_px(x), _py(y), Palette.warn, 10, speed: 90, life: 0.4, size: 2.4);

      case CutRefused(:final x, :final y):
        // They pushed toward open ground without the cut key: say what to do.
        _popup(_px(x), _py(y) - 46, 'Hold SHIFT to cut', Palette.warn, 18);

      case CutCancelled(:final x, :final y):
        // A small relieved puff: you backed out.
        _ring(_px(x), _py(y), 44, Palette.accent, duration: 0.3);
        _burst(_px(x), _py(y), Palette.accent, 10, speed: 70, life: 0.35);

      case PlayerDied(:final x, :final y):
        final px = _px(x);
        final py = _py(y);
        _burst(px, py, Palette.accent, 40, speed: 260, life: 0.9, size: 3.2);
        _burst(px, py, Palette.enemy, 24, speed: 180, life: 0.8, size: 2.6);
        _ring(px, py, 130, Palette.enemy, duration: 0.5);
        _addShake(0.9);

      case EnemyDied(:final x, :final y, :final kind):
        final px = _px(x);
        final py = _py(y);
        final color = Palette.forEnemy(kind);
        _burst(px, py, color, 26, speed: 200, life: 0.7, size: 3);
        _ring(px, py, 60, color, duration: 0.4);
        _popup(px, py - 6, '+${GameConfig.enemyKillPoints}', color, 18);
        _addShake(0.2);

      case PickedUp(:final element, :final x, :final y):
        final color = Palette.forElement(element);
        _ring(_px(x), _py(y), 70, color, duration: 0.45);
        _burst(_px(x), _py(y), color, 18, speed: 150, life: 0.6, size: 2.6);

      case DropCollected(:final effect, :final x, :final y):
        final color = effect.good ? Palette.good : Palette.bad;
        _ring(_px(x), _py(y), 90, color, duration: 0.5);
        _burst(_px(x), _py(y), color, 24, speed: 180, life: 0.7, size: 3);
        _popup(_px(x), _py(y) - 10, effect.label, color, 26, icon: effect);
        if (!effect.good) _addShake(0.25);

      case ShieldBroke(:final x, :final y):
        _ring(_px(x), _py(y), 80, Palette.accent, duration: 0.4);
        _popup(_px(x), _py(y) - 10, 'BLOCKED', Palette.accent, 20);

      case ItemUsed(:final element, :final x, :final y):
        _itemBurst(element, _px(x), _py(y));

      case LevelCleared():
        // Confetti from the top of the field.
        final colors = [
          Palette.accent,
          Palette.fire,
          Palette.water,
          Palette.air,
          Palette.earth,
          Palette.enemyDrifter,
        ];
        for (var i = 0; i < 160; i++) {
          _spark(
            GameConfig.viewWidth * (0.2 + _rng.nextDouble() * 0.6),
            GameConfig.playfieldTop + 10,
            colors[i % colors.length],
            speed: 260,
            life: 1.8,
            size: 3.4,
            gravity: 220,
            angle: pi / 2 + (_rng.nextDouble() - 0.5) * 2.2,
          );
        }
        _addShake(0.35);
    }
  }

  void _flashField(Color color, double strength) {
    _flashColor = color;
    _flash = max(_flash, strength);
  }

  /// Each element has its own big signature when fired: a field flash, its
  /// name, and a burst shaped like the element.
  void _itemBurst(ElementType element, double x, double y) {
    final color = Palette.forElement(element);
    _popup(x, y - 40, '${element.name.toUpperCase()}!', color, 38,
        element: element);
    switch (element) {
      case ElementType.fire:
        // A fireball: a hot white core, a wall of rising embers, two
        // shockwaves, and flame tongues licking outward.
        _flashField(color, 0.35);
        _burst(x, y, const Color(0xFFFFF4C2), 30, speed: 120, life: 0.4, size: 5);
        _burst(x, y, color, 120, speed: 300, life: 1.2, size: 3.6, gravity: -180);
        _burst(x, y, Palette.enemyDasher, 60,
            speed: 220, life: 1.0, size: 2.8, gravity: -220);
        _burst(x, y, Palette.enemy, 30, speed: 160, life: 0.8, size: 2.4, gravity: -120);
        _ring(x, y, 160, const Color(0xFFFFF4C2), duration: 0.35);
        _ring(x, y, 260, color, duration: 0.6, delay: 0.05);
        _ring(x, y, 340, Palette.enemy, duration: 0.8, delay: 0.12);
        _addShake(0.5);
      case ElementType.water:
        // A splash: droplets thrown up that fall back, and wide ripples
        // rolling out across the field.
        _flashField(color, 0.3);
        for (var i = 0; i < 90; i++) {
          _spark(x, y, i.isEven ? color : Palette.air,
              speed: 320,
              life: 1.2,
              size: 3.2,
              gravity: 520,
              angle: -pi / 2 + (_rng.nextDouble() - 0.5) * 2.4);
        }
        for (var i = 0; i < 6; i++) {
          _ring(x, y, 120 + i * 55, color, duration: 0.9, delay: i * 0.1);
        }
        _addShake(0.3);
      case ElementType.air:
        // A gust: sparks flung out on a spiral, and very fast thin rings.
        _flashField(color, 0.25);
        for (var i = 0; i < 120; i++) {
          final a = i * 0.35;
          _spark(x + cos(a) * 12, y + sin(a) * 12, color,
              speed: 420, life: 0.6, size: 2.2, angle: a + pi / 2.6);
        }
        _burst(x, y, Palette.water, 30, speed: 260, life: 0.5, size: 1.8);
        for (var i = 0; i < 3; i++) {
          _ring(x, y, 220 + i * 70, color, duration: 0.4, delay: i * 0.07);
        }
        _addShake(0.25);
      case ElementType.earth:
        // A quake: heavy debris that falls, a dust cloud, and a slow, wide
        // ground wave.
        _flashField(color, 0.4);
        _burst(x, y, color, 110, speed: 260, life: 1.3, size: 4.5, gravity: 420);
        _burst(x, y, const Color(0xFF8A6A3A), 60,
            speed: 140, life: 1.6, size: 6, gravity: 300);
        _burst(x, y, Palette.line, 40, speed: 90, life: 1.4, size: 2.5, gravity: -30);
        _ring(x, y, 240, color, duration: 0.7);
        _ring(x, y, 380, const Color(0xFF8A6A3A), duration: 1.0, delay: 0.1);
        _addShake(1);
    }
  }

  /// Ambient effects: the cut's sparks, and while an element runs, its aura
  /// on the player AND on the open line, plus a puff when it runs out.
  void _ambient(double dt) {
    final w = session.walker;
    final px = _px(w.column + 0.5);
    final py = _py(w.row + 0.5);
    final element = session.effects.dominant;
    final tint = element == null ? Palette.cut : Palette.forElement(element);

    // An element just ran out: a puff so you notice the protection is gone.
    final running = {for (final e in session.effects.running) e.key};
    for (final gone in _wasRunning.difference(running)) {
      final c = Palette.forElement(gone);
      _ring(px, py, 90, c, duration: 0.45);
      _burst(px, py, c, 30, speed: 160, life: 0.5, size: 2.4);
      _popup(px, py - 50, '${gone.name.toUpperCase()} faded', c, 18);
    }
    _wasRunning
      ..clear()
      ..addAll(running);

    if (w.isDrawing) {
      _spark(px, py, tint, speed: 35, life: 0.4, size: 2);
    }
    if (element == null) return;

    // A random cell of the open line, for effects that run along it.
    (double, double)? trailPoint() {
      final cells = w.trailCells;
      if (cells.isEmpty) return null;
      final i = cells.elementAt(_rng.nextInt(cells.length));
      return (
        _px(session.grid.columnOf(i) + 0.5),
        _py(session.grid.rowOf(i) + 0.5),
      );
    }

    switch (element) {
      case ElementType.fire:
        // The player smoulders; the line itself burns.
        for (var i = 0; i < 3; i++) {
          _spark(px + (_rng.nextDouble() - 0.5) * 40, py, tint,
              speed: 70, life: 0.8, size: 3.4, gravity: -200);
        }
        _spark(px, py, Palette.enemyDasher,
            speed: 50, life: 0.6, size: 2.4, gravity: -220);
        for (var i = 0; i < 4; i++) {
          final p = trailPoint();
          if (p == null) break;
          _spark(p.$1, p.$2, i.isEven ? tint : Palette.enemyDasher,
              speed: 30, life: 0.7, size: 2.8, gravity: -160);
        }
      case ElementType.water:
        // Ripples off the player; the line shimmers with droplets.
        _ripple -= dt;
        if (_ripple <= 0) {
          _ripple = 0.3;
          _ring(px, py, 80, tint, duration: 0.7);
        }
        _spark(px, py, tint, speed: 60, life: 0.7, size: 2.6);
        for (var i = 0; i < 3; i++) {
          final p = trailPoint();
          if (p == null) break;
          _spark(p.$1, p.$2, i.isEven ? tint : Palette.air,
              speed: 25, life: 0.6, size: 2.2, gravity: 60);
        }
      case ElementType.air:
        // Wind streaks peeling off behind, and gusts along the line.
        final back = w.lastDirection;
        final a = back == null
            ? _rng.nextDouble() * 2 * pi
            : atan2(-back.dr.toDouble(), -back.dc.toDouble());
        for (var i = 0; i < 4; i++) {
          _spark(px, py, tint,
              speed: 260, life: 0.35, size: 1.8,
              angle: a + (_rng.nextDouble() - 0.5) * 0.9);
        }
        for (var i = 0; i < 2; i++) {
          final p = trailPoint();
          if (p == null) break;
          _spark(p.$1, p.$2, tint, speed: 120, life: 0.3, size: 1.6);
        }
      case ElementType.earth:
        break; // instant, no lasting aura
    }
  }

  /// The aura drawn round the player while an element runs: its own shape,
  /// plus an arc that empties as the time runs out (and blinks at the end).
  void _renderAura(Canvas canvas) {
    final element = session.effects.dominant;
    if (element == null || element.duration <= 0) return;
    final w = session.walker;
    final c = Offset(
      GameConfig.cellCenterX(w.column),
      GameConfig.cellCenterY(w.row),
    );
    final color = Palette.forElement(element);
    final left = session.effects.remaining(element);
    final frac = (left / element.duration).clamp(0.0, 1.0);
    final base = GameConfig.playerDiameter / 2;

    // A wide soft glow under everything.
    canvas.drawCircle(
      c,
      base + 34,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    switch (element) {
      case ElementType.fire:
        // Flame tongues: a jagged crown that flickers.
        final flame = Path();
        const n = 18;
        for (var i = 0; i <= n * 2; i++) {
          final a = i * pi / n;
          final flick = sin(_time * 13 + i * 2.1) * 0.5 + 0.5;
          final rad = i.isEven ? base + 10 + 16 * flick : base + 4;
          final pt = c + Offset(cos(a), sin(a)) * rad;
          i == 0 ? flame.moveTo(pt.dx, pt.dy) : flame.lineTo(pt.dx, pt.dy);
        }
        flame.close();
        canvas
          ..drawPath(
            flame,
            Paint()
              ..color = color.withValues(alpha: 0.55)
              ..blendMode = BlendMode.plus,
          )
          ..drawPath(
            flame,
            Paint()
              ..color = Palette.enemyDasher.withValues(alpha: 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
      case ElementType.water:
        // Bubbles orbiting on a wobbling ring.
        for (var i = 0; i < 8; i++) {
          final a = _time * 1.6 + i * pi / 4;
          final rad = base + 16 + 5 * sin(_time * 3 + i);
          final b = c + Offset(cos(a), sin(a)) * rad;
          canvas
            ..drawCircle(b, 5 + 2 * sin(_time * 4 + i),
                Paint()..color = color.withValues(alpha: 0.75))
            ..drawCircle(
              b,
              5 + 2 * sin(_time * 4 + i),
              Paint()
                ..color = Palette.air
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2,
            );
        }
      case ElementType.air:
        // Three swirling arcs, spinning fast.
        for (var i = 0; i < 3; i++) {
          final start = _time * 7 + i * 2 * pi / 3;
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: base + 14 + i * 7),
            start,
            1.6,
            false,
            Paint()
              ..color = color.withValues(alpha: 0.85 - i * 0.2)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4 - i.toDouble()
              ..strokeCap = StrokeCap.round,
          );
        }
      case ElementType.earth:
        break;
    }

    // The countdown: an arc that empties clockwise. Blinks in the last second.
    final blink = left < 1 && (_time * 10).floor().isEven;
    if (!blink) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: base + 26),
        -pi / 2,
        2 * pi * frac,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // --- frame --------------------------------------------------------------

  @override
  void update(double dt) {
    _time += dt;
    _flash = max(0, _flash - dt * 1.6);
    for (final e in session.takeEvents()) {
      _handle(e);
    }
    if (session.status == SessionStatus.playing) _ambient(dt);

    for (final s in _sparks) {
      s.life -= dt;
      s.vy += s.gravity * dt;
      s.vx *= 1 - min(1, 1.6 * dt); // drag
      s.vy *= 1 - min(1, 1.6 * dt);
      s.x += s.vx * dt;
      s.y += s.vy * dt;
    }
    _sparks.removeWhere((s) => s.life <= 0);

    for (final r in _rings) {
      r.age += dt;
    }
    _rings.removeWhere((r) => r.age >= r.duration);

    for (final p in _popups) {
      p.age += dt;
    }
    _popups.removeWhere((p) => p.age >= 1.1);

    // Screen shake: a trembling camera that settles quickly.
    _shake = max(0, _shake - dt * 2.4);
    if (_shake > 0) {
      final m = _shake * _shake * 13;
      onShake(Offset((_rng.nextDouble() - 0.5) * 2 * m,
          (_rng.nextDouble() - 0.5) * 2 * m));
      _wasShaking = true;
    } else if (_wasShaking) {
      onShake(Offset.zero);
      _wasShaking = false;
    }
  }

  @override
  void render(Canvas canvas) {
    // The field lights up in the element's colour for a moment.
    if (_flash > 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          GameConfig.playfieldLeft,
          GameConfig.playfieldTop,
          GameConfig.playfieldWidth,
          GameConfig.playfieldHeight,
        ),
        Paint()
          ..color = _flashColor.withValues(alpha: _flash)
          ..blendMode = BlendMode.plus,
      );
    }

    if (session.status == SessionStatus.playing) _renderAura(canvas);

    for (final r in _rings) {
      if (r.age < 0) continue; // still waiting for its delay
      final t = (r.age / r.duration).clamp(0.0, 1.0);
      final ease = 1 - pow(1 - t, 3).toDouble(); // fast out, slow settle
      canvas.drawCircle(
        Offset(r.x, r.y),
        r.radius * ease,
        Paint()
          ..color = r.color.withValues(alpha: 1 - t)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + 5 * (1 - t)
          ..blendMode = BlendMode.plus,
      );
    }

    // Additive blending makes overlapping sparks bloom like light.
    final paint = Paint()..blendMode = BlendMode.plus;
    for (final s in _sparks) {
      final t = (s.life / s.maxLife).clamp(0.0, 1.0);
      paint.color = s.color.withValues(alpha: t);
      canvas.drawCircle(Offset(s.x, s.y), s.size * (0.4 + 0.6 * t), paint);
    }

    for (final p in _popups) {
      final t = p.age / 1.1;
      final text = TextPaint(
        style: TextStyle(
          color: p.color.withValues(alpha: 1 - t * t),
          fontSize: p.size * (1 + 0.25 * (1 - t)),
          fontWeight: FontWeight.bold,
        ),
      );
      text.render(
        canvas,
        p.text,
        Vector2(p.x, p.y - 46 * t),
        anchor: Anchor.center,
      );
      final iconAt = Offset(p.x, p.y - 46 * t - p.size * 1.4);
      final iconColor = p.color.withValues(alpha: 1 - t * t);
      final icon = p.icon;
      if (icon != null) {
        paintDropIcon(canvas, icon, iconAt, p.size * 1.5, iconColor);
      }
      final element = p.element;
      if (element != null) {
        paintElementIcon(canvas, element, iconAt, p.size * 1.5, iconColor);
      }
    }
  }
}
