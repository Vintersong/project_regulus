import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'components/playfield_frame.dart';
import 'config.dart';
import 'palette.dart';

class RegulusGame extends FlameGame {
  RegulusGame()
      : super(
          camera: CameraComponent.withFixedResolution(
            width: GameConfig.viewWidth,
            height: GameConfig.viewHeight,
          ),
        );

  @override
  Color backgroundColor() => Palette.background;

  @override
  Future<void> onLoad() async {
    // World coordinates match the logical view: (0,0) is top-left.
    camera.viewfinder.anchor = Anchor.topLeft;
    world.add(PlayfieldFrame());
  }
}
