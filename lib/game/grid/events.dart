import 'drops.dart';
import 'enemy_body.dart';
import 'powerups.dart';

/// Things that happened in the session, for the effects layer to react to.
/// The session only reports them; it never knows how they are drawn.
///
/// Positions ([x], [y]) are in fractional grid cells.
sealed class GameEvent {
  const GameEvent();
}

/// A cut closed (or an earthquake split the ground) and ground was won.
class Captured extends GameEvent {
  const Captured({
    required this.cells,
    required this.points,
    required this.combo,
    required this.x,
    required this.y,
  });

  /// Flat grid indices of the cells just claimed.
  final List<int> cells;
  final int points;
  final int combo;

  /// Centre of the new ground.
  final double x;
  final double y;
}

/// The player left the border and began a cut. ([x], [y]) is where it began.
class CutStarted extends GameEvent {
  const CutStarted(this.x, this.y);
  final double x;
  final double y;
}

/// The player tried to leave the border without holding the cut key.
class CutRefused extends GameEvent {
  const CutRefused(this.x, this.y);
  final double x;
  final double y;
}

/// A short cut was backed out of completely.
class CutCancelled extends GameEvent {
  const CutCancelled(this.x, this.y);
  final double x;
  final double y;
}

class PlayerDied extends GameEvent {
  const PlayerDied(this.x, this.y);
  final double x;
  final double y;
}

class EnemyDied extends GameEvent {
  const EnemyDied(this.x, this.y, this.kind);
  final double x;
  final double y;
  final EnemyKind kind;
}

class PickedUp extends GameEvent {
  const PickedUp(this.element, this.x, this.y);
  final ElementType element;
  final double x;
  final double y;
}

class ItemUsed extends GameEvent {
  const ItemUsed(this.element, this.x, this.y);
  final ElementType element;
  final double x;
  final double y;
}

/// A field was cleared: a layer, or (if [levelDone]) the whole level.
class LevelCleared extends GameEvent {
  const LevelCleared(this.bonus, {this.levelDone = true});
  final int bonus;
  final bool levelDone;
}

/// A mystery drop was collected and its effect applied.
class DropCollected extends GameEvent {
  const DropCollected(this.effect, this.x, this.y);
  final DropEffect effect;
  final double x;
  final double y;
}

/// A shield soaked up a hit.
class ShieldBroke extends GameEvent {
  const ShieldBroke(this.x, this.y);
  final double x;
  final double y;
}
