import 'package:flutter_test/flutter_test.dart';
import 'package:project_regulus/game/config.dart';
import 'package:project_regulus/game/grid/claim_grid.dart';
import 'package:project_regulus/game/grid/direction.dart';
import 'package:project_regulus/game/grid/walker.dart';

void main() {
  latchTests();
  test('walks along the rim and is blocked by the grid bounds', () {
    final grid = ClaimGrid(columns: 10, rows: 8);
    final w = Walker(grid, column: 5, row: 7);
    expect(w.step(Direction.left), StepResult.moved);
    expect(w.column, 4);
    expect(w.step(Direction.down), StepResult.blocked);
    expect(w.isDrawing, isFalse);
  });

  test('cutting in draws a trail', () {
    final grid = ClaimGrid(columns: 10, rows: 8);
    final w = Walker(grid, column: 5, row: 7);
    expect(w.step(Direction.up), StepResult.moved);
    expect(w.isDrawing, isTrue);
    expect(grid.stateAt(5, 6), CellState.trail);
  });

  test('a long cut cannot be crossed or backed out of', () {
    final grid = ClaimGrid(columns: 10, rows: 30);
    final w = Walker(grid, column: 5, row: 29);
    // Past the retract limit you are committed.
    for (var i = 0; i < GameConfig.retractCells + 2; i++) {
      expect(w.step(Direction.up), StepResult.moved);
    }
    expect(w.canRetract, isFalse);
    expect(w.step(Direction.down), StepResult.blocked);
  });

  group('the cut key', () {
    test('without it, leaving the border is refused and nothing changes', () {
      final grid = ClaimGrid(columns: 10, rows: 8);
      final w = Walker(grid, column: 5, row: 7);
      final edges = grid.edgeRevision;
      expect(w.step(Direction.up, canStartCut: false), StepResult.cutRefused);
      expect((w.column, w.row), (5, 7));
      expect(w.isDrawing, isFalse);
      expect(grid.stateAt(5, 6), CellState.empty);
      expect(grid.edgeRevision, edges);
    });

    test('without it, walking along the border still works', () {
      final grid = ClaimGrid(columns: 10, rows: 8);
      final w = Walker(grid, column: 5, row: 7);
      expect(w.step(Direction.left, canStartCut: false), StepResult.moved);
      expect(w.column, 4);
    });

    test('with it, the cut starts', () {
      final grid = ClaimGrid(columns: 10, rows: 8);
      final w = Walker(grid, column: 5, row: 7);
      expect(w.step(Direction.up, canStartCut: true), StepResult.moved);
      expect(w.isDrawing, isTrue);
    });

    test('once a cut is under way it carries on without the key', () {
      final grid = ClaimGrid(columns: 10, rows: 8);
      final w = Walker(grid, column: 5, row: 7);
      w.step(Direction.up, canStartCut: true);
      expect(w.step(Direction.up, canStartCut: false), StepResult.moved);
      expect(w.step(Direction.left, canStartCut: false), StepResult.moved);
    });

    test('backing out of a short cut does not need the key either', () {
      final grid = ClaimGrid(columns: 10, rows: 8);
      final w = Walker(grid, column: 5, row: 7);
      w.step(Direction.up, canStartCut: true);
      expect(w.step(Direction.down, canStartCut: false), StepResult.retracted);
      expect(w.isDrawing, isFalse);
    });
  });

  group('backing out of a short cut', () {
    test('stepping straight back undoes it cell by cell', () {
      final grid = ClaimGrid(columns: 10, rows: 8);
      final w = Walker(grid, column: 5, row: 7);
      w.step(Direction.up);
      w.step(Direction.up);
      expect(w.canRetract, isTrue);
      expect(w.retractDirection, Direction.down);

      expect(w.step(Direction.down), StepResult.retracted);
      expect(grid.stateAt(5, 5), CellState.empty); // the head cell is gone
      expect((w.column, w.row), (5, 6));
      expect(w.isDrawing, isTrue);

      expect(w.step(Direction.down), StepResult.retracted);
      expect(grid.stateAt(5, 6), CellState.empty);
      expect((w.column, w.row), (5, 7)); // back on the border
      expect(w.isDrawing, isFalse);
    });

    test('a full back-out leaves nothing behind, not even a bump', () {
      final grid = ClaimGrid(columns: 10, rows: 8);
      final w = Walker(grid, column: 5, row: 7);
      final edges = grid.edgeRevision;
      w.step(Direction.up);
      w.step(Direction.down);
      expect(w.isDrawing, isFalse);
      expect(grid.stateAt(5, 6), CellState.empty);
      expect(grid.edgeRevision, edges); // no edge cell was ever made
      expect(grid.claimedCount, 0);
    });

    test('only the way back retracts; other directions carry on', () {
      final grid = ClaimGrid(columns: 10, rows: 8);
      final w = Walker(grid, column: 5, row: 7);
      w.step(Direction.up);
      expect(w.retractDirection, Direction.down);
      expect(w.step(Direction.left), StepResult.moved); // turning is a cut
      expect(w.retractDirection, Direction.right); // back is now "right"
    });

    test('you are committed past the limit', () {
      final grid = ClaimGrid(columns: 10, rows: 30);
      final w = Walker(grid, column: 5, row: 29);
      for (var i = 0; i < GameConfig.retractCells; i++) {
        w.step(Direction.up);
      }
      expect(w.canRetract, isTrue); // exactly at the limit: still free
      w.step(Direction.up);
      expect(w.canRetract, isFalse);
      expect(w.retractDirection, isNull);
    });

    test('not cutting means nothing to retract', () {
      final grid = ClaimGrid(columns: 10, rows: 8);
      final w = Walker(grid, column: 5, row: 7);
      expect(w.canRetract, isFalse);
      expect(w.retractDirection, isNull);
    });
  });

  test('closing a trail captures the smaller side', () {
    final grid = ClaimGrid(columns: 10, rows: 8);
    // Cut from the bottom rim up to the top rim at column 3.
    final w = Walker(grid, column: 3, row: 7);
    for (var i = 0; i < 6; i++) {
      expect(w.step(Direction.up), StepResult.moved);
    }
    expect(w.step(Direction.up), StepResult.closedTrail);
    expect(w.isDrawing, isFalse);
    // Left pocket (cols 1-2) = 12 cells, right pocket = 30. Smaller wins.
    expect(grid.stateAt(1, 3), CellState.claimed);
    expect(grid.stateAt(6, 3), CellState.empty);
    expect(grid.stateAt(3, 3), CellState.edge);
    expect(grid.claimedFraction, closeTo(12 / grid.playableCount, 1e-9));
  });
}

void latchTests() {
  group('line latching', () {
    // Border ring plus a claimed block leaves a spur line: build by hand.
    ClaimGrid gridWithSpur() {
      final grid = ClaimGrid(columns: 20, rows: 20);
      for (var r = 5; r < 19; r++) {
        grid.setState(10, r, CellState.edge); // a line rising from the bottom
      }
      return grid;
    }

    test('a turn pressed just past the junction slides back onto the line', () {
      final grid = gridWithSpur();
      final w = Walker(grid, column: 12, row: 19);
      // Up from (12,19) is open ground; without the key it would be refused.
      expect(w.step(Direction.up, canStartCut: false, latchCells: 8),
          StepResult.moved);
      expect((w.column, w.row), (11, 19));
    });

    test('a turn pressed just before the junction slides forward', () {
      final grid = gridWithSpur();
      final w = Walker(grid, column: 7, row: 19);
      w.step(Direction.up, canStartCut: false, latchCells: 8);
      expect(w.column, 8);
    });

    test('too far away, or latching off, still refuses', () {
      final grid = ClaimGrid(columns: 60, rows: 20);
      for (var r = 5; r < 19; r++) {
        grid.setState(10, r, CellState.edge);
      }
      // 20 cells from the spur and 34 from the side rim: out of reach.
      final w = Walker(grid, column: 30, row: 19);
      expect(w.step(Direction.up, canStartCut: false, latchCells: 8),
          StepResult.cutRefused);
      final v = Walker(grid, column: 12, row: 19);
      expect(v.step(Direction.up, canStartCut: false), StepResult.cutRefused);
    });
  });
}
