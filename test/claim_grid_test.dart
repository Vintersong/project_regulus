import 'package:flutter_test/flutter_test.dart';
import 'package:project_regulus/game/grid/claim_grid.dart';

void main() {
  test('new grid has an edge rim and an open interior', () {
    final grid = ClaimGrid(columns: 10, rows: 8);
    expect(grid.stateAt(0, 0), CellState.edge);
    expect(grid.stateAt(9, 7), CellState.edge);
    expect(grid.stateAt(5, 4), CellState.empty);
    expect(grid.claimedFraction, 0);
  });

  test('a wall splits the interior into two regions', () {
    final grid = ClaimGrid(columns: 10, rows: 8);
    // Vertical wall at column 4 across the whole interior.
    for (var r = 1; r < 7; r++) {
      grid.setState(4, r, CellState.edge);
    }
    final regions = grid.findEmptyRegions();
    expect(regions.length, 2);
    expect(regions.map((r) => r.size).toList()..sort(), [18, 24]);
  });

  test('claiming a region updates the captured fraction', () {
    final grid = ClaimGrid(columns: 10, rows: 8);
    for (var r = 1; r < 7; r++) {
      grid.setState(4, r, CellState.edge);
    }
    final regions = grid.findEmptyRegions();
    final smaller = regions.reduce((a, b) => a.size <= b.size ? a : b);
    grid.claimRegions(regions, (region) => identical(region, smaller));
    expect(grid.claimedFraction, closeTo(18 / grid.playableCount, 1e-9));
  });
}
