import 'dart:collection';
import 'dart:typed_data';

import '../config.dart';

/// State of one cell of the claim grid.
enum CellState {
  /// Open territory: enemies roam here, the player cuts into it.
  empty,

  /// Captured territory. This is what reveals the plate.
  claimed,

  /// Walkable border: the playfield rim plus the rim of claimed areas.
  edge,

  /// The line the player is currently drawing. Deadly while open.
  trail,
}

/// A connected pocket of empty cells, produced when a trail splits the field.
class Region {
  Region(this.cells);

  /// Flat cell indices (row * columns + column).
  final List<int> cells;

  int get size => cells.length;
}

/// Coarse grid of cell states. Independent of screen size so difficulty is the
/// same on every device (see the 2 Nov implementation plan in the handoff).
class ClaimGrid {
  ClaimGrid({
    this.columns = GameConfig.gridColumns,
    this.rows = GameConfig.gridRows,
  }) : _cells = Uint8List(columns * rows) {
    _drawRim();
  }

  final int columns;
  final int rows;
  final Uint8List _cells;

  int get cellCount => columns * rows;

  /// Cells inside the rim: the territory that can actually be won.
  int get playableCount => (columns - 2) * (rows - 2);

  int _claimedCount = 0;

  /// Number of captured cells.
  int get claimedCount => _claimedCount;

  /// Share of the playable area captured so far, 0.0 to 1.0.
  double get claimedFraction => _claimedCount / playableCount;

  /// Share to capture to clear the level. The session sets it per level.
  double captureTarget = GameConfig.captureTarget;

  bool get targetReached => claimedFraction >= captureTarget;

  int index(int column, int row) => row * columns + column;
  int columnOf(int index) => index % columns;
  int rowOf(int index) => index ~/ columns;

  bool inBounds(int column, int row) =>
      column >= 0 && column < columns && row >= 0 && row < rows;

  CellState stateAt(int column, int row) =>
      CellState.values[_cells[index(column, row)]];

  CellState stateAtIndex(int i) => CellState.values[_cells[i]];

  void setState(int column, int row, CellState state) =>
      setStateAtIndex(index(column, row), state);

  void setStateAtIndex(int i, CellState state) {
    final old = CellState.values[_cells[i]];
    if (old == CellState.claimed) _claimedCount--;
    if (state == CellState.claimed) _claimedCount++;
    // Cheap change counters, so drawing can rebuild only what changed.
    if (old == CellState.claimed || state == CellState.claimed) {
      claimedRevision++;
    }
    if (old == CellState.edge || state == CellState.edge) edgeRevision++;
    _cells[i] = state.index;
  }

  /// Bumps whenever a cell becomes or stops being captured.
  int claimedRevision = 0;

  /// Bumps whenever a cell becomes or stops being edge.
  int edgeRevision = 0;

  /// Flags (1) for every edge cell connected to ([column], [row]) through
  /// other edge cells: the walkable network the player can actually reach.
  /// Edge cells walled off inside captured ground look walkable but are not.
  Uint8List reachableEdges(int column, int row) {
    final flags = Uint8List(cellCount);
    final start = index(column, row);
    if (_cells[start] != CellState.edge.index) return flags;

    final queue = Queue<int>()..add(start);
    flags[start] = 1;
    while (queue.isNotEmpty) {
      final i = queue.removeFirst();
      final c = columnOf(i);
      final r = rowOf(i);
      for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nc = c + dc;
        final nr = r + dr;
        if (!inBounds(nc, nr)) continue;
        final n = index(nc, nr);
        if (flags[n] == 1 || _cells[n] != CellState.edge.index) continue;
        flags[n] = 1;
        queue.add(n);
      }
    }
    return flags;
  }

  /// The outer rim starts as walkable edge; everything inside is open.
  void _drawRim() {
    for (var c = 0; c < columns; c++) {
      setState(c, 0, CellState.edge);
      setState(c, rows - 1, CellState.edge);
    }
    for (var r = 0; r < rows; r++) {
      setState(0, r, CellState.edge);
      setState(columns - 1, r, CellState.edge);
    }
  }

  /// Back to a fresh field: open interior inside the edge rim.
  void reset() {
    _cells.fillRange(0, _cells.length, 0);
    _claimedCount = 0;
    claimedRevision++;
    edgeRevision++;
    _drawRim();
  }

  /// Finds every connected pocket of [CellState.empty] cells (4-connectivity).
  ///
  /// Call this after the trail is closed and turned into edge cells: the trail
  /// has split open territory into pockets, and the capture rule decides which
  /// of them get claimed.
  List<Region> findEmptyRegions() {
    final seen = Uint8List(cellCount);
    final regions = <Region>[];

    for (var start = 0; start < cellCount; start++) {
      if (seen[start] == 1 || _cells[start] != CellState.empty.index) continue;

      final cells = <int>[];
      final queue = Queue<int>()..add(start);
      seen[start] = 1;

      while (queue.isNotEmpty) {
        final i = queue.removeFirst();
        cells.add(i);
        final c = columnOf(i);
        final r = rowOf(i);
        for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final nc = c + dc;
          final nr = r + dr;
          if (!inBounds(nc, nr)) continue;
          final n = index(nc, nr);
          if (seen[n] == 1 || _cells[n] != CellState.empty.index) continue;
          seen[n] = 1;
          queue.add(n);
        }
      }
      regions.add(Region(cells));
    }
    return regions;
  }

  /// Claims every region [shouldClaim] approves. Returns the cells claimed.
  List<int> claimRegions(
    List<Region> regions,
    bool Function(Region region) shouldClaim,
  ) {
    final won = <int>[];
    for (final region in regions) {
      if (!shouldClaim(region)) continue;
      for (final i in region.cells) {
        setStateAtIndex(i, CellState.claimed);
        won.add(i);
      }
    }
    return won;
  }
}
