import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';
import '../grid/claim_grid.dart';
import '../grid/enemy_body.dart';
import '../grid/patrol_body.dart';
import '../grid/session.dart';
import '../palette.dart';

/// Draws the session's enemies and the waiting pickup. One component for all
/// of them: enemies come and go every few seconds, so there is nothing to add
/// or remove per frame. Placeholder shapes until the engraved creatures land.
class ActorsLayer extends PositionComponent {
  ActorsLayer(this.session) : super(priority: 5);

  final GameSession session;
  double _time = 0;

  final Paint _ring = Paint()
    ..color = Palette.letterbox
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  final Paint _giftBody = Paint()..color = Palette.drop;
  final Paint _giftRibbon = Paint()..color = Palette.accent;

  @override
  void update(double dt) => _time += dt;

  /// A buried drop: a gift box. It says "surprise" without saying whether the
  /// surprise is good or bad.
  void _renderGift(Canvas canvas, Offset c) {
    // Box, then a slightly wider lid.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - 9, c.dy - 2, 18, 12),
        const Radius.circular(2),
      ),
      _giftBody,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - 11, c.dy - 7, 22, 6),
        const Radius.circular(2),
      ),
      _giftBody,
    );
    // Ribbon down the middle and a bow on top.
    canvas.drawRect(Rect.fromLTWH(c.dx - 2, c.dy - 7, 4, 17), _giftRibbon);
    for (final side in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx + side * 4.5, c.dy - 10),
          width: 8,
          height: 6,
        ),
        _giftRibbon,
      );
    }
  }

  /// A border patrol: a white-hot spark that spins as it runs the edge.
  void _renderPatrol(Canvas canvas, PatrolBody p) {
    final c = Offset(
      GameConfig.cellCenterX(p.column),
      GameConfig.cellCenterY(p.row),
    );
    canvas.drawCircle(
      c,
      18,
      Paint()
        ..color = Palette.accent.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // A comet tail along the cells it just ran through, fading out behind.
    var from = c;
    for (var k = 0; k < p.history.length; k++) {
      final (hc, hr) = p.history[k];
      final to = Offset(GameConfig.cellCenterX(hc), GameConfig.cellCenterY(hr));
      final t = 1 - k / p.history.length;
      canvas
        ..drawLine(
          from,
          to,
          Paint()
            ..color = Palette.patrolTail.withValues(alpha: 0.35 * t)
            ..strokeWidth = 14 * t + 2
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        )
        ..drawLine(
          from,
          to,
          Paint()
            ..color = Palette.patrolTail.withValues(alpha: 0.9 * t)
            ..strokeWidth = 5 * t + 1
            ..strokeCap = StrokeCap.round,
        );
      from = to;
    }

    // A four-point star, spinning.
    final star = Path();
    for (var i = 0; i < 8; i++) {
      final radius = i.isEven ? 14.0 : 4.5;
      final a = _time * 4 + i * pi / 4;
      final pt = Offset(c.dx + cos(a) * radius, c.dy + sin(a) * radius);
      i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
    }
    star.close();
    canvas
      ..drawPath(star, Paint()..color = Palette.letterbox..style = PaintingStyle.stroke..strokeWidth = 4)
      ..drawPath(star, Paint()..color = Palette.patrol);
  }

  /// Each kind has its own silhouette AND its own motion, so you can read what
  /// it will do at a glance: a spiked ball, an arrowhead with an eye, a
  /// shuriken that spins, a ring with an orbiting bead, a striped snake.
  void _renderEnemy(Canvas canvas, EnemyBody e, Offset c) {
    final r = GameConfig.enemyDiameter / 2;
    final color = Palette.forEnemy(e.kind);

    // A soft halo in the kind's colour, so enemies pop against the ground.
    void halo(Offset at, double radius, [double alpha = 0.22]) {
      canvas.drawCircle(
        at,
        radius,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }

    final fill = Paint()..color = color;
    final dark = Paint()..color = Palette.letterbox;
    final light = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85);

    switch (e.kind) {
      case EnemyKind.bouncer:
        // A spiked ball, tumbling: eight spikes round a dark-cored body.
        halo(c, r * 1.7);
        final spikes = Path();
        for (var i = 0; i < 16; i++) {
          final rad = i.isEven ? r * 1.35 : r * 0.9;
          final a = _time * 1.5 + i * pi / 8;
          final pt = Offset(c.dx + cos(a) * rad, c.dy + sin(a) * rad);
          i == 0 ? spikes.moveTo(pt.dx, pt.dy) : spikes.lineTo(pt.dx, pt.dy);
        }
        spikes.close();
        canvas
          ..drawPath(spikes, fill)
          ..drawPath(spikes, _ring)
          ..drawCircle(c, r * 0.5, dark)
          ..drawCircle(c + Offset(-r * 0.15, -r * 0.15), r * 0.18, light);

      case EnemyKind.hunter:
        // A sharp arrowhead with a notched tail and a glowing eye, pointing
        // where it is heading.
        halo(c, r * 1.8);
        final head = Path()
          ..moveTo(r * 1.7, 0)
          ..lineTo(-r * 1.1, -r * 1.15)
          ..lineTo(-r * 0.55, 0)
          ..lineTo(-r * 1.1, r * 1.15)
          ..close();
        canvas
          ..save()
          ..translate(c.dx, c.dy)
          ..rotate(e.heading)
          ..drawPath(head, fill)
          ..drawPath(head, _ring)
          ..drawCircle(Offset(r * 0.35, 0), r * 0.42, dark)
          ..drawCircle(Offset(r * 0.45, 0), r * 0.2, light)
          ..restore();

      case EnemyKind.dasher:
        // A four-bladed shuriken: it spins, and spins hard mid-burst, with a
        // streak behind it.
        final k = e.dashing ? 1.35 : 1.0;
        halo(c, r * (e.dashing ? 2.8 : 1.8), e.dashing ? 0.35 : 0.22);
        final spin = _time * (e.dashing ? 18 : 3);
        final star = Path();
        for (var i = 0; i < 8; i++) {
          final rad = (i.isEven ? r * 1.5 : r * 0.45) * k;
          final a = spin + i * pi / 4;
          final pt = Offset(c.dx + cos(a) * rad, c.dy + sin(a) * rad);
          i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
        }
        star.close();
        canvas
          ..drawPath(star, fill)
          ..drawPath(star, _ring)
          ..drawCircle(c, r * 0.3, dark);

      case EnemyKind.snake:
        // Tail first so the head draws on top. Body parts over captured
        // ground are skipped: the snake disappears into it.
        final grid = session.grid;
        final body = e.segments;
        final stripe = Paint()..color = Palette.letterbox.withValues(alpha: 0.45);
        for (var k = body.length - 1; k >= 0; k--) {
          final p = body[k];
          final col = p.x.floor();
          final row = p.y.floor();
          if (!grid.inBounds(col, row)) continue;
          final s = grid.stateAt(col, row);
          if (s != CellState.empty && s != CellState.trail) continue;
          final t = k / max(1, body.length);
          final seg = Offset(
            GameConfig.cellCenterX(p.x - 0.5),
            GameConfig.cellCenterY(p.y - 0.5),
          );
          final rr = r * (1.0 - 0.5 * t);
          canvas
            ..drawCircle(seg, rr, fill)
            ..drawCircle(seg, rr, _ring);
          if (k.isOdd) canvas.drawCircle(seg, rr * 0.55, stripe);
        }
        halo(c, r * 1.7);
        canvas
          ..drawCircle(c, r * 1.25, fill)
          ..drawCircle(c, r * 1.25, _ring);
        // Two eyes, looking where it is heading.
        final look = Offset(cos(e.heading), sin(e.heading)) * (r * 0.25);
        final side = Offset(-sin(e.heading), cos(e.heading)) * (r * 0.5);
        for (final o in [side, -side]) {
          canvas
            ..drawCircle(c + o + look * 0.4, r * 0.34, light)
            ..drawCircle(c + o + look * 1.6, r * 0.17, dark);
        }

      case EnemyKind.drifter:
        // A thick ring with a bright bead orbiting it: light and slippery.
        halo(c, r * 1.7);
        canvas
          ..drawCircle(
            c,
            r,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 7,
          )
          ..drawCircle(
            c,
            r + 3.5,
            Paint()
              ..color = Palette.letterbox
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5,
          )
          ..drawCircle(
            c,
            r - 3.5,
            Paint()
              ..color = Palette.letterbox
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5,
          );
        final bead = c + Offset(cos(_time * 4), sin(_time * 4)) * r;
        canvas
          ..drawCircle(bead, 6, light)
          ..drawCircle(bead, 6, _ring);
    }
  }

  /// The item slot, top-centre in the margin: an empty ring, or the held
  /// element glowing in its colour (press Space to use it).
  void _renderSlot(Canvas canvas) {
    final c = Offset(GameConfig.viewWidth / 2, 20);
    const r = 13.0;
    final item = session.held;
    if (item != null) {
      final color = Palette.forElement(item);
      final pulse = 1 + 0.15 * sin(_time * 5);
      canvas.drawCircle(
        c,
        r * 1.5 * pulse,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(c, r, Paint()..color = color);
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Palette.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  /// Earthquake cracks: they race outward from the player, then fade out.
  void _renderCracks(Canvas canvas) {
    const growSeconds = 0.35;
    for (final crack in session.cracks) {
      final grown = (crack.age / growSeconds).clamp(0.0, 1.0);
      final count = (crack.cells.length * grown).ceil();
      if (count == 0) continue;
      final fade = 1 -
          ((crack.age - 0.5) / (GameConfig.crackSeconds - 0.5)).clamp(0.0, 1.0);

      final path = Path();
      for (var i = 0; i < count; i++) {
        final cell = crack.cells[i];
        final x = GameConfig.cellCenterX(session.grid.columnOf(cell));
        final y = GameConfig.cellCenterY(session.grid.rowOf(cell));
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Palette.earth.withValues(alpha: 0.5 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Palette.earth.withValues(alpha: fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    _renderCracks(canvas);

    for (final e in session.enemies) {
      final c = Offset(
        GameConfig.cellCenterX(e.x - 0.5),
        GameConfig.cellCenterY(e.y - 0.5),
      );
      _renderEnemy(canvas, e, c);
    }

    for (final p in session.patrols) {
      _renderPatrol(canvas, p);
    }

    _renderSlot(canvas);

    // Buried mystery drops: a soft shimmer and a gift box, never the answer.
    for (final d in session.drops) {
      final c = Offset(
        GameConfig.cellCenterX(session.grid.columnOf(d.cell)),
        GameConfig.cellCenterY(session.grid.rowOf(d.cell)),
      );
      final pulse = 0.5 + 0.5 * sin(_time * 3 + d.cell);
      canvas.drawCircle(
        c,
        16 + 4 * pulse,
        Paint()
          ..color = Palette.drop.withValues(alpha: 0.18 + 0.15 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      _renderGift(canvas, c);
    }

    final p = session.pickup;
    if (p != null) {
      final c = Offset(
        GameConfig.cellCenterX(session.grid.columnOf(p.cell)),
        GameConfig.cellCenterY(session.grid.rowOf(p.cell)),
      );
      final color = Palette.forElement(p.element);
      final pulse = 1 + 0.12 * sin(_time * 6);
      // Dimmed while the slot is full: it can't be picked up right now.
      final dim = session.held == null ? 1.0 : 0.4;
      final r = GameConfig.pickupDiameter / 2 * pulse;
      // Blink during the last few seconds so it reads as expiring.
      final fading = p.timeLeft < 3 && (_time * 8).floor().isEven;
      if (!fading) {
        canvas.drawCircle(
          c,
          r + 6,
          Paint()
            ..color = color.withValues(alpha: 0.3 * dim)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: dim));
        canvas.drawCircle(c, r, _ring);
      }
    }
  }
}
