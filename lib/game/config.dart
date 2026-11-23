/// Fixed logical layout. The camera letterboxes this to any window size.
abstract final class GameConfig {
  // Logical view (16:10 landscape).
  static const double viewWidth = 1280;
  static const double viewHeight = 800;

  // Claim grid. Each cell is one unit of capturable territory.
  static const double cellSize = 5;
  static const int gridColumns = 240;
  static const int gridRows = 144;

  static const double playfieldWidth = gridColumns * cellSize; // 1200
  static const double playfieldHeight = gridRows * cellSize; // 720
  static const double playfieldLeft = (viewWidth - playfieldWidth) / 2;
  static const double playfieldTop = (viewHeight - playfieldHeight) / 2;

  // Player: drawn as a dot this wide (logical px), but its logic position is a
  // single grid cell. Try 128 for a bolder look.
  static const double playerDiameter = 64;

  // Grid cells the player crosses per second (60 cells = 300 px/s).
  static const double playerCellsPerSecond = 60;

  static double cellCenterX(num column) =>
      playfieldLeft + (column + 0.5) * cellSize;
  static double cellCenterY(num row) => playfieldTop + (row + 0.5) * cellSize;

  static const int startingLives = 3;

  // Enemies. How many, of which kinds, how fast relative to this, and the\n  // respawn delay are set per level in levels.dart. Speed is in cells/second.
  static const double enemyCellsPerSecond = 28;
  static const double enemyDiameter = 40;

  // Scoring. Ground is worth [pointsPerCell] a cell times the combo; each
  // capture within [comboSeconds] of the last raises the combo, up to
  // [maxCombo]. Clearing a level pays a flat bonus plus a bonus per life left.
  static const int pointsPerCell = 5;
  static const int enemyKillPoints = 250;
  static const double comboSeconds = 6;
  static const int maxCombo = 5;
  static const int levelClearBonus = 5000;
  static const int lifeBonus = 1000;

  // Levels (see levels.dart): each clear adds one spare life, up to [maxLives].
  // Clearing a layer that isn't a level's last pays [layerClearBonus] (no
  // life), and each deeper layer fields [enemiesPerLayer] more enemies.
  static const int layerClearBonus = 1500;
  static const int enemiesPerLayer = 1;

  // How fast the colours crossfade to a new layer's look (higher = faster;
  // about 3 / this seconds to settle).
  static const double layerFadeRate = 3;
  static const int maxLives = 5;

  // A cut this short (in cells) can still be backed out of by stepping
  // straight back along it. Longer than this and you are committed. 12 cells
  // is about 0.2 s of walking: enough to undo an accidental tap, not enough
  // to dodge an enemy.
  static const int retractCells = 12;

  // Line latching: pushing toward a wall or open ground (cut key not held)
  // while a line leading that way starts within this many cells along the
  // border slides you onto it. 0 turns it off.
  static const int latchCells = 8;

  // Mystery drops: buried in the field at the start of a level. Collected by
  // a capture that covers them, or by touching them mid-cut. [dropGoodChance]
  // is the odds the effect helps (0.5 = a straight gamble).
  static const int dropsPerLevel = 4;
  static const double dropGoodChance = 0.5;
  static const double dropCollectRadiusCells = 6;
  static const int jackpotPoints = 2000;
  static const int bombKills = 2;
  static const double slowEnemyScale = 0.5;
  static const double rushEnemyScale = 1.7;
  static const double sluggishPlayerScale = 0.5;
  static const double shieldGraceSeconds = 1.2;

  // Hunters turn at most this fast (radians per second) toward the player.
  static const double hunterTurnRate = 1.6;

  // Dashers: a burst this many times their cruising speed, for this long.
  static const double dashSpeedScale = 2.5;
  static const double dashSeconds = 0.35;

  // Border patrols: sparks that run along the edge, where you are normally
  // safe. Slower than the player, but they home in on where you are.
  static const double patrolCellsPerSecond = 22;
  static const double patrolChaseBias = 0.7; // share of junctions aimed at you
  static const double patrolContactRadiusCells = 2.5;

  // Snakes: a head plus this many body segments, one every [snakeSegmentGap]
  // recorded path samples. [snakeWobble] sets how hard it slithers.
  static const int snakeSegments = 9;
  static const int snakeSegmentGap = 4;
  static const double snakePathSpacing = 0.6;
  static const double snakeWobble = 1.8;

  // An enemy this close (in cells) to a player who is mid-cut is a hit. The
  // dot is drawn much bigger than one cell, so this is generous on purpose.
  static const double contactRadiusCells = 5;

  // Elemental pickups: one at a time, dropped in open territory. How often\n  // is set per level.
  static const double pickupLifetimeSeconds = 12;
  static const double pickupDiameter = 36;

  // Mid-cut, a pickup this close (in cells) is collected. Generous, because
  // the dot is drawn much bigger than the single cell the player occupies.
  static const double pickupCollectRadiusCells = 6;

  // Earthquake cracks: how long they stay drawn (seconds), and how jagged
  // they are (chance per step of lurching sideways instead of straight on).
  static const double crackSeconds = 1.4;
  static const double crackJitter = 0.3;

  // Air trade-off: you are faster, but so is everything else.
  static const double airPlayerSpeedScale = 1.8;
  static const double airEnemySpeedScale = 1.5;

  // Whether the shine shader's FlutterFragCoord() is in device pixels rather
  // than local coordinates. It depends on the renderer; set after checking on
  // screen. When true the shader is handed the canvas transform to undo it.
  static const bool shaderDeviceSpace = false;

  // Share of the field to capture to clear a level (Qix used 75%).
  static const double captureTarget = 0.75;
}

