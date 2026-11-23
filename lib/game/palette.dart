import 'dart:ui';

import 'grid/enemy_body.dart';
import 'grid/powerups.dart';

/// The look of one layer of a level: the open ground, and the engraved plate
/// revealed where ground is captured ([plate] is the metal, [ink] the
/// engraving). Deeper layers run from teal down through blue and violet to a
/// smouldering red, so you can see how far down you are.
class LayerLook {
  const LayerLook({required this.ground, required this.plate, required this.ink});
  final Color ground;
  final Color plate;
  final Color ink;
}

/// Placeholder palette: engraved green-teal with a glowing cyan accent.
abstract final class Palette {
  static const Color letterbox = Color(0xFF050D0B);
  static const Color background = Color(0xFF0B1F1C);
  static const Color line = Color(0xFF7FBFAE);
  static const Color claimed = Color(0xFF15463F);
  static const Color enemy = Color(0xFFE8423F); // bouncer
  static const Color enemyHunter = Color(0xFFB65CE8);
  static const Color enemyDasher = Color(0xFFFF9A2E);
  static const Color enemyDrifter = Color(0xFFF26BA8);
  /// Warning amber: you are exposed (mid-cut) but can still back out.
  static const Color warn = Color(0xFFFFB04D);
  static const Color enemySnake = Color(0xFF9BE15D);
  static const Color patrol = Color(0xFFFFFFFF);
  static const Color fire = Color(0xFFFF8A3D);
  static const Color water = Color(0xFF4FA8FF);
  static const Color air = Color(0xFFE6F4FF);
  static const Color earth = Color(0xFFC9A45C);
  static const Color accent = Color(0xFF3FF2E6);

  /// The open line while cutting. Hot magenta, drawn over a dark outline: the
  /// complement of the teal ground, and far from every element's colour
  /// (fire orange, water blue, air white, earth tan), so a powered cut always
  /// looks different from a plain one.
  static const Color cut = Color(0xFFFF3FD2);

  /// The comet tail behind a border patrol: danger red, unlike any ground.
  static const Color patrolTail = Color(0xFFFF3B3B);
  static const Color drop = Color(0xFFE6C8FF); // mystery drop
  static const Color good = Color(0xFF7DF29B);
  static const Color bad = Color(0xFFFF5C7A);

  /// Layer looks, shallowest first. A deeper layer than listed uses the last.
  static const List<LayerLook> layers = [
    LayerLook( // 1: teal, the surface
      ground: Color(0xFF0B1F1C),
      plate: Color(0xFF12453D),
      ink: Color(0xFF80D9BD),
    ),
    LayerLook( // 2: deep blue
      ground: Color(0xFF0B1530),
      plate: Color(0xFF172A57),
      ink: Color(0xFF8CADF2),
    ),
    LayerLook( // 3: violet
      ground: Color(0xFF1A0D2E),
      plate: Color(0xFF381A52),
      ink: Color(0xFFD19EF2),
    ),
    LayerLook( // 4: ember, the core
      ground: Color(0xFF260C0E),
      plate: Color(0xFF571719),
      ink: Color(0xFFF59E80),
    ),
  ];

  static LayerLook forLayer(int layer) =>
      layers[(layer - 1).clamp(0, layers.length - 1)];

  static Color forEnemy(EnemyKind kind) => switch (kind) {
        EnemyKind.bouncer => enemy,
        EnemyKind.hunter => enemyHunter,
        EnemyKind.dasher => enemyDasher,
        EnemyKind.drifter => enemyDrifter,
        EnemyKind.snake => enemySnake,
      };

  /// Tint for an element: its pickup, and the player and trail while it runs.
  static Color forElement(ElementType type) => switch (type) {
        ElementType.fire => fire,
        ElementType.water => water,
        ElementType.air => air,
        ElementType.earth => earth,
      };
}
