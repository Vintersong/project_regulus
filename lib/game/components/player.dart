import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';
import '../grid/powerups.dart';
import '../grid/walker.dart';
import '../palette.dart';

/// The player: a glowing dot. Visually [GameConfig.playerDiameter] wide, but
/// logically one grid cell (see [Walker]). All movement lives in the session;
/// this only follows the walker.
class Player extends PositionComponent {
  Player(this.walker, this.effects, {required this.isArmed})
      : super(
          size: Vector2.all(GameConfig.playerDiameter),
          anchor: Anchor.center,
          priority: 10,
        ) {
    _syncPosition();
  }

  final Walker walker;
  final ActiveEffects effects;

  /// Whether the cut key is held, so the next step off the border would start
  /// a cut.
  final bool Function() isArmed;

  bool _powered = false;

  final Paint _fill = Paint()..color = Palette.accent;
  final Paint _glow = Paint()
    ..color = Palette.accent.withValues(alpha: 0.35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  final Paint _ring = Paint()
    ..color = Palette.letterbox
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  double _time = 0;

  @override
  void update(double dt) {
    _time += dt;
    _syncPosition();
    final element = effects.dominant;
    _powered = element != null;
    final tint = element == null ? Palette.accent : Palette.forElement(element);
    _fill.color = tint;
    // While an element runs: a wider, brighter glow and a tinted ring.
    _glow
      ..color = tint.withValues(alpha: _powered ? 0.7 : 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _powered ? 22 : 10);
    _ring.color = _powered ? tint.withValues(alpha: 0.9) : Palette.letterbox;
  }

  void _syncPosition() {
    position.setValues(
      GameConfig.cellCenterX(walker.column),
      GameConfig.cellCenterY(walker.row),
    );
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x / 2;

    // Mid-cut you are exposed: a pulsing ring says so. Amber while you can
    // still back out (step straight back), red and faster once committed.
    if (walker.isDrawing) {
      final committed = !walker.canRetract;
      final color = committed ? Palette.enemy : Palette.warn;
      final pulse = 0.5 + 0.5 * sin(_time * (committed ? 14 : 8));
      canvas
        ..drawCircle(
          center,
          radius + 12,
          Paint()
            ..color = color.withValues(alpha: 0.25 + 0.2 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        )
        ..drawCircle(
          center,
          radius + 6 + 5 * pulse,
          Paint()
            ..color = color.withValues(alpha: 0.5 + 0.5 * pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = committed ? 5 : 4,
        );
    }

    // Armed: the cut key is held on the border, so moving into open ground
    // will start a cut. A steady thin ring, calmer than the cutting pulse.
    if (!walker.isDrawing && isArmed()) {
      canvas.drawCircle(
        center,
        radius + 7,
        Paint()
          ..color = Palette.warn.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    canvas.drawCircle(center, radius, _glow);
    canvas.drawCircle(center, radius - 2, _fill);
    if (_powered) {
      // Tinted ring sits outside a dark inner ring so the fill still pops.
      canvas.drawCircle(center, radius - 6, Paint()
        ..color = Palette.letterbox
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
    canvas.drawCircle(center, radius - 2, _ring);
  }
}
