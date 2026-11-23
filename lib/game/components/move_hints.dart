import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';
import '../grid/claim_grid.dart';
import '../grid/direction.dart';
import '../grid/session.dart';
import '../palette.dart';

/// Chevrons around the player showing where they can go and what it does.
///
/// The dot is 64 px wide and covers the line it stands on, so the lines
/// themselves can't answer "can I walk that way?". These do, at its edge:
///
///  * a white chevron: that way is walkable border;
///  * a faint hollow chevron: open ground, but the cut key isn't held, so
///    moving that way does nothing;
///  * a glowing amber chevron: open ground and the cut key IS held, so moving
///    that way STARTS A CUT;
///  * a filled amber chevron (early in a cut): step this way to undo it;
///  * a bright filled cyan chevron (while cutting): that way is border, so
///    moving finishes the cut.
///
/// No chevron means that way is blocked (captured ground, your own line, or
/// the edge of the field).
class MoveHints extends PositionComponent {
  MoveHints(this.session) : super(priority: 9);

  final GameSession session;
  double _time = 0;

  static const double _distance = 46; // from the player's centre, px
  static const double _size = 9;

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) {
    if (session.status != SessionStatus.playing) return;
    final w = session.walker;
    final grid = session.grid;
    final center = Offset(
      GameConfig.cellCenterX(w.column),
      GameConfig.cellCenterY(w.row),
    );
    final pulse = 0.65 + 0.35 * sin(_time * 5);

    for (final d in Direction.values) {
      final c = w.column + d.dc;
      final r = w.row + d.dr;
      if (!grid.inBounds(c, r)) continue;

      _Hint? hint = switch (grid.stateAt(c, r)) {
        CellState.edge => w.isDrawing ? _Hint.close : _Hint.walk,
        CellState.empty => w.isDrawing
            ? null
            : (session.canStartCut ? _Hint.cut : _Hint.locked),
        _ => null, // claimed ground or your own line: blocked
      };
      // Stepping straight back along a short cut undoes it.
      if (d == w.retractDirection) hint = _Hint.back;
      if (hint == null) continue;

      final at = center + Offset(d.dc * _distance, d.dr * _distance);
      final angle = atan2(d.dr.toDouble(), d.dc.toDouble());
      final path = Path()
        ..moveTo(_size, 0)
        ..lineTo(-_size * 0.7, -_size * 0.9)
        ..lineTo(-_size * 0.3, 0)
        ..lineTo(-_size * 0.7, _size * 0.9)
        ..close();

      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(angle)
        // A dark outline under everything, so a chevron stays readable on top
        // of the bright edge lines and the foil.
        ..drawPath(
          path,
          Paint()
            ..color = Palette.letterbox
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeJoin = StrokeJoin.round,
        );
      switch (hint) {
        case _Hint.walk:
          // White: border you can walk along.
          canvas.drawPath(path, Paint()..color = const Color(0xFFF2FFFB));
        case _Hint.locked:
          // Faint and hollow: open ground, but the cut key isn't held, so
          // moving this way does nothing.
          canvas.drawPath(
            path,
            Paint()
              ..color = Palette.line.withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..strokeJoin = StrokeJoin.round,
          );
        case _Hint.cut:
          // Glowing amber: the cut key is held, so moving this way WILL
          // start a cut. A warning colour, not a friendly one.
          canvas
            ..drawPath(
              path,
              Paint()
                ..color = Palette.warn.withValues(alpha: 0.6 * pulse)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
            )
            ..drawPath(path, Paint()..color = Palette.warn);
        case _Hint.back:
          // Filled amber: step this way to undo the cut.
          canvas.drawPath(
            path,
            Paint()..color = Palette.warn.withValues(alpha: 0.6 + 0.4 * pulse),
          );
        case _Hint.close:
          // Glowing filled accent: border, moving finishes the cut.
          canvas
            ..drawPath(
              path,
              Paint()
                ..color = Palette.accent.withValues(alpha: 0.7 * pulse)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
            )
            ..drawPath(path, Paint()..color = Palette.accent);
      }
      canvas.restore();
    }
  }
}

enum _Hint { walk, locked, cut, close, back }
