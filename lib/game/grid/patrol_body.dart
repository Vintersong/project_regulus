import 'dart:math';

import '../config.dart';
import 'claim_grid.dart';
import 'direction.dart';

/// A spark that runs along the edge cells: the border, your finished cuts and
/// earthquake cracks. It threatens the one place you are normally safe.
///
/// It only ever steps onto [CellState.edge] cells, one at a time, so it can't
/// leave the border network or enter open ground.
class PatrolBody {
  PatrolBody({required this.column, required this.row});

  int column;
  int row;

  /// The last few cells it ran through, newest first. Drawn as a comet tail so
  /// you can see which way it is going and where it has been.
  final List<(int, int)> history = [];
  static const int historyLength = 14;

  int _fromColumn = -1;
  int _fromRow = -1;
  double _progress = 0;

  /// Puts the spark on a cell and forgets where it came from.
  void place(int column, int row) {
    this.column = column;
    this.row = row;
    _fromColumn = -1;
    _fromRow = -1;
    _progress = 0;
    history.clear();
  }

  /// Advances along the edge. At each junction it usually heads toward
  /// ([targetColumn], [targetRow]) and otherwise picks any way on, and it
  /// never turns straight back unless it is at a dead end.
  void update(
    double dt,
    ClaimGrid grid,
    Random random, {
    required int targetColumn,
    required int targetRow,
    double speedScale = 1,
  }) {
    _progress += dt * GameConfig.patrolCellsPerSecond * speedScale;
    while (_progress >= 1) {
      _progress -= 1;
      _step(grid, random, targetColumn, targetRow);
    }
  }

  void _step(ClaimGrid grid, Random random, int targetColumn, int targetRow) {
    final options = <(int, int)>[];
    for (final d in Direction.values) {
      final c = column + d.dc;
      final r = row + d.dr;
      if (grid.inBounds(c, r) && grid.stateAt(c, r) == CellState.edge) {
        options.add((c, r));
      }
    }
    if (options.isEmpty) return; // boxed in; nothing to walk on

    final forward =
        options.where((o) => o != (_fromColumn, _fromRow)).toList();
    final pool = forward.isEmpty ? options : forward; // dead end: turn around

    (int, int) pick;
    if (random.nextDouble() < GameConfig.patrolChaseBias) {
      int dist((int, int) o) {
        final dc = o.$1 - targetColumn;
        final dr = o.$2 - targetRow;
        return dc * dc + dr * dr;
      }

      pick = pool.reduce((a, b) => dist(a) <= dist(b) ? a : b);
    } else {
      pick = pool[random.nextInt(pool.length)];
    }

    _fromColumn = column;
    _fromRow = row;
    history.insert(0, (column, row));
    if (history.length > historyLength) history.removeLast();
    column = pick.$1;
    row = pick.$2;
  }
}
