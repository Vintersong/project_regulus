import 'dart:ui';

import 'dart:math' show min;

import 'package:flame/components.dart';

import '../config.dart';
import '../grid/session.dart';
import '../palette.dart';

/// Outline of the claimable area. Placeholder until the plate art lands.
class PlayfieldFrame extends PositionComponent {
  PlayfieldFrame()
      : super(
          position: Vector2(GameConfig.playfieldLeft, GameConfig.playfieldTop),
          size: Vector2(GameConfig.playfieldWidth, GameConfig.playfieldHeight),
        );

  final Paint _paint = Paint()
    ..color = Palette.line
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _paint);
  }
}

/// The open ground of the playfield, in the current layer's colour. Drawn
/// under everything else; eases to a new colour when you go down a layer.
class LayerBackdrop extends PositionComponent {
  LayerBackdrop(this.session)
      : super(
          position: Vector2(GameConfig.playfieldLeft, GameConfig.playfieldTop),
          size: Vector2(GameConfig.playfieldWidth, GameConfig.playfieldHeight),
          priority: -1,
        );

  final GameSession session;
  final Paint _paint = Paint()..color = Palette.layers.first.ground;

  @override
  void update(double dt) {
    final target = Palette.forLayer(session.layer).ground;
    _paint.color = Color.lerp(
      _paint.color,
      target,
      min(1.0, dt * GameConfig.layerFadeRate),
    )!;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _paint);
  }
}
