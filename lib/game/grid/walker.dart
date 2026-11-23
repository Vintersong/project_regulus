import '../config.dart';
import 'capture_rule.dart';
import 'claim_grid.dart';
import 'direction.dart';

enum StepResult {
  /// Wall, claimed ground, or the player's own open line: no movement.
  blocked,

  /// Moved along the edge, or extended the open trail.
  moved,

  /// Stepped back onto an edge: the trail closed and territory was captured.
  closedTrail,

  /// Stepped back along a short fresh cut, undoing a cell of it.
  retracted,

  /// Open ground is that way, but the cut key is not held: a cut is only
  /// started on purpose, so nothing happened.
  cutRefused,
}

/// The player's logical position on the grid and the trail rules. Pure Dart,
/// so it can be tested without Flame.
class Walker {
  Walker(this.grid, {required this.column, required this.row})
      : edgeColumn = column,
        edgeRow = row;

  final ClaimGrid grid;
  int column;
  int row;

  final List<int> _trail = [];

  /// Cells won by the most recent capture (empty if it won nothing).
  List<int> lastClaimed = const [];

  /// Direction of the last successful step.
  Direction? lastDirection;

  bool get isDrawing => _trail.isNotEmpty;

  /// Cells of the open trail, in order. Read-only; for drawing.
  Iterable<int> get trailCells => _trail;

  /// The last edge cell the player stood on. While cutting, this is where the
  /// cut began, so it names the walkable network the player belongs to.
  int edgeColumn;
  int edgeRow;

  /// Flat grid index of the player's cell.
  int get index => grid.index(column, row);

  /// Whether the open cut is still short enough to back out of. Past
  /// [GameConfig.retractCells] cells you are committed.
  bool get canRetract => isDrawing && _trail.length <= GameConfig.retractCells;

  /// The cell one step back along the cut: the one before the player's, or
  /// the border cell the cut started from.
  (int, int)? get _previousCell {
    if (_trail.isEmpty) return null;
    if (_trail.length >= 2) {
      final i = _trail[_trail.length - 2];
      return (grid.columnOf(i), grid.rowOf(i));
    }
    return (edgeColumn, edgeRow);
  }

  /// Which way undoes the last cell of the cut, or null if you are committed
  /// (or not cutting).
  Direction? get retractDirection {
    final back = _previousCell;
    if (back == null || !canRetract) return null;
    for (final d in Direction.values) {
      if (column + d.dc == back.$1 && row + d.dr == back.$2) return d;
    }
    return null;
  }

  /// Erases the open trail (a death) without capturing anything.
  void abortTrail() {
    for (final i in _trail) {
      grid.setStateAtIndex(i, CellState.empty);
    }
    _trail.clear();
  }

  /// Puts the player back on an edge cell. Forgets the trail list only; call
  /// [abortTrail] first if its cells are still on the grid.
  void reset(int column, int row) {
    this.column = column;
    this.row = row;
    edgeColumn = column;
    edgeRow = row;
    _trail.clear();
    lastDirection = null;
  }

  /// Advances one cell in [direction]. [enemyCells] are the flat indices of
  /// every enemy, used by the capture rule when a trail closes.
  ///
  /// Leaving the border into open ground starts a cut, which only happens
  /// when [canStartCut] is true (the cut key is held). Once a cut is under
  /// way it carries on regardless.
  StepResult step(
    Direction direction, {
    Set<int> enemyCells = const {},
    bool canStartCut = true,
    int latchCells = 0,
  }) {
    final nc = column + direction.dc;
    final nr = row + direction.dr;
    if (!grid.inBounds(nc, nr)) return StepResult.blocked;

    // Backing out of a short cut: step straight back along it and it is
    // undone, cell by cell, with nothing left behind.
    if (direction == retractDirection) {
      grid.setStateAtIndex(_trail.removeLast(), CellState.empty);
      column = nc;
      row = nr;
      lastDirection = direction;
      return StepResult.retracted;
    }

    switch (grid.stateAt(nc, nr)) {
      case CellState.claimed:
        return _latch(direction, latchCells) ?? StepResult.blocked;

      case CellState.trail:
        return StepResult.blocked;

      case CellState.empty:
        // Leaving the edge starts a trail, but only on purpose.
        if (!isDrawing && !canStartCut) {
          return _latch(direction, latchCells) ?? StepResult.cutRefused;
        }
        grid.setState(nc, nr, CellState.trail);
        _trail.add(grid.index(nc, nr));
        column = nc;
        row = nr;
        lastDirection = direction;
        return StepResult.moved;

      case CellState.edge:
        column = nc;
        row = nr;
        lastDirection = direction;
        edgeColumn = nc;
        edgeRow = nr;
        if (!isDrawing) return StepResult.moved;
        _closeTrail(enemyCells);
        return StepResult.closedTrail;
    }
  }

  /// Line latching. The player is on the border and pushes [direction] where
  /// that way is not walkable. If a line leading that way starts within
  /// [reach] cells along the border (ahead or behind), take one step toward
  /// it, so holding the turn key slides you onto the line instead of needing
  /// a pixel-perfect press on the exact cell. Returns null when there is
  /// nothing to latch onto.
  StepResult? _latch(Direction direction, int reach) {
    if (reach <= 0 || isDrawing) return null;
    // The line to slide along is perpendicular to the way we want to turn.
    final along = direction.dc == 0
        ? const [Direction.left, Direction.right]
        : const [Direction.up, Direction.down];
    Direction? best;
    var bestDistance = reach + 1;
    for (final side in along) {
      for (var d = 1; d <= reach; d++) {
        final c = column + side.dc * d;
        final r = row + side.dr * d;
        // The way there must be border all the way.
        if (!grid.inBounds(c, r) || grid.stateAt(c, r) != CellState.edge) break;
        final tc = c + direction.dc;
        final tr = r + direction.dr;
        if (grid.inBounds(tc, tr) && grid.stateAt(tc, tr) == CellState.edge) {
          // Nearest junction wins; on a tie, keep going the way we were.
          if (d < bestDistance || (d == bestDistance && side == lastDirection)) {
            best = side;
            bestDistance = d;
          }
          break;
        }
      }
    }
    if (best == null) return null;
    column += best.dc;
    row += best.dr;
    lastDirection = best;
    edgeColumn = column;
    edgeRow = row;
    return StepResult.moved;
  }

  /// An earthquake: [cracks] become border, any open trail is finished, and
  /// the pockets they wall off are captured by the normal rule. The player
  /// ends up standing on border, no longer drawing.
  void shatter(Iterable<int> cracks, {Set<int> enemyCells = const {}}) {
    for (final i in cracks) {
      grid.setStateAtIndex(i, CellState.edge);
    }
    _closeTrail(enemyCells);
    // The player's own cell is now border: that is the network they are on.
    edgeColumn = column;
    edgeRow = row;
  }

  void _closeTrail(Set<int> enemyCells) {
    // The finished line becomes new walkable edge, splitting the open field.
    for (final i in _trail) {
      grid.setStateAtIndex(i, CellState.edge);
    }
    _trail.clear();

    final regions = grid.findEmptyRegions();
    lastClaimed = grid.claimRegions(
      regions,
      (region) => shouldClaimRegion(
        region: region,
        allRegions: regions,
        enemyCells: enemyCells,
      ),
    );
  }
}
