import 'package:flutter_test/flutter_test.dart';
import 'package:project_regulus/game/grid/capture_rule.dart';
import 'package:project_regulus/game/grid/claim_grid.dart';

/// 10x8 grid split by a wall at column 4: left pocket 18 cells, right 24.
ClaimGrid _split() {
  final grid = ClaimGrid(columns: 10, rows: 8);
  for (var r = 1; r < 7; r++) {
    grid.setState(4, r, CellState.edge);
  }
  return grid;
}

Set<int> _claimed(ClaimGrid grid, Set<int> enemies) {
  final regions = grid.findEmptyRegions();
  grid.claimRegions(
    regions,
    (r) => shouldClaimRegion(
        region: r, allRegions: regions, enemyCells: enemies),
  );
  return {
    for (var i = 0; i < grid.cellCount; i++)
      if (grid.stateAtIndex(i) == CellState.claimed) i
  };
}

void main() {
  test('claims the pocket without an enemy', () {
    final grid = _split();
    final claimed = _claimed(grid, {grid.index(7, 3)}); // enemy on the right
    expect(claimed.length, 18); // left pocket only
    expect(claimed.contains(grid.index(2, 3)), isTrue);
  });

  test('enemy in the small pocket leaves it open, claims the big one', () {
    final grid = _split();
    final claimed = _claimed(grid, {grid.index(2, 3)});
    expect(claimed.length, 24);
  });

  test('enemies in every pocket: claims all but the largest', () {
    final grid = _split();
    final claimed = _claimed(grid, {grid.index(2, 3), grid.index(7, 3)});
    expect(claimed.length, 18);
    expect(claimed.contains(grid.index(2, 3)), isTrue);
  });
}
