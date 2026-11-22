import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';
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
