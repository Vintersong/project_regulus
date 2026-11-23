import 'package:flutter_test/flutter_test.dart';
import 'package:project_regulus/game/grid/claim_grid.dart';
import 'package:project_regulus/game/grid/direction.dart';
import 'package:project_regulus/game/grid/session.dart';
import 'package:project_regulus/game/grid/walker.dart';

void main() {
  group('reachable edges', () {
    test('the whole rim is one walkable network', () {
      final grid = ClaimGrid(columns: 12, rows: 8);
      final reach = grid.reachableEdges(0, 0);
      for (var c = 0; c < 12; c++) {
        expect(reach[grid.index(c, 0)], 1);
        expect(reach[grid.index(c, 7)], 1);
      }
      expect(reach[grid.index(5, 4)], 0); // open ground is not edge
    });

    test('a finished cut joins the network', () {
      final grid = ClaimGrid(columns: 12, rows: 8);
      for (var r = 1; r < 7; r++) {
        grid.setState(5, r, CellState.edge); // a wall rim to rim
      }
      final reach = grid.reachableEdges(0, 0);
      expect(reach[grid.index(5, 3)], 1);
    });

    test('an old line walled off inside captured ground is not reachable', () {
      final grid = ClaimGrid(columns: 20, rows: 12);
      // An island: a ring of edge with claimed ground inside, nowhere near
      // the rim.
      for (var c = 5; c <= 9; c++) {
        for (var r = 4; r <= 8; r++) {
          final ring = c == 5 || c == 9 || r == 4 || r == 8;
          grid.setState(c, r, ring ? CellState.edge : CellState.claimed);
        }
      }
      final reach = grid.reachableEdges(0, 0);
      expect(reach[grid.index(5, 4)], 0); // looks walkable, is not
      expect(reach[grid.index(0, 0)], 1);
      // From the island itself it is the other way round.
      final island = grid.reachableEdges(5, 4);
      expect(island[grid.index(5, 4)], 1);
      expect(island[grid.index(0, 0)], 0);
    });

    test('asking from a non-edge cell reaches nothing', () {
      final grid = ClaimGrid(columns: 12, rows: 8);
      expect(grid.reachableEdges(5, 4).every((f) => f == 0), isTrue);
    });
  });

  group('revisions', () {
    test('claimed and edge revisions only move when those cells change', () {
      final grid = ClaimGrid(columns: 12, rows: 8);
      final claimed = grid.claimedRevision;
      final edge = grid.edgeRevision;
      grid.setState(5, 4, CellState.trail);
      expect(grid.claimedRevision, claimed);
      expect(grid.edgeRevision, edge);
      grid.setState(5, 4, CellState.claimed);
      expect(grid.claimedRevision, greaterThan(claimed));
      expect(grid.edgeRevision, edge);
      grid.setState(6, 4, CellState.edge);
      expect(grid.edgeRevision, greaterThan(edge));
    });

    test('reset bumps both so a new level redraws everything', () {
      final grid = ClaimGrid(columns: 12, rows: 8);
      final claimed = grid.claimedRevision;
      final edge = grid.edgeRevision;
      grid.reset();
      expect(grid.claimedRevision, greaterThan(claimed));
      expect(grid.edgeRevision, greaterThan(edge));
    });
  });

  group('which network the player is on', () {
    test('the walker remembers where its cut began', () {
      final grid = ClaimGrid(columns: 12, rows: 8);
      final w = Walker(grid, column: 5, row: 7);
      w.step(Direction.up); // leaves the border
      w.step(Direction.up);
      expect(w.isDrawing, isTrue);
      expect((w.edgeColumn, w.edgeRow), (5, 7)); // the cut's start
    });

    test('closing a cut puts the walker on the network again', () {
      final grid = ClaimGrid(columns: 12, rows: 8);
      final w = Walker(grid, column: 5, row: 7);
      for (var i = 0; i < 6; i++) {
        w.step(Direction.up);
      }
      w.step(Direction.up); // reaches the top rim
      expect((w.edgeColumn, w.edgeRow), (5, 0));
    });

    test('a trail can be drawn from the cells it covers', () {
      final grid = ClaimGrid(columns: 12, rows: 8);
      final w = Walker(grid, column: 5, row: 7);
      w.step(Direction.up);
      w.step(Direction.up);
      expect(w.trailCells.toList(),
          [grid.index(5, 6), grid.index(5, 5)]);
    });
  });

  group('dev helper', () {
    test('debugClaimRect claims the inside and borders it with edge', () {
      final s = GameSession(
        grid: ClaimGrid(columns: 20, rows: 12),
        enemyCount: 0,
        patrolCount: 0,
        spawnPickups: false,
      );
      s.debugClaimRect(2, 2, 6, 6);
      expect(s.grid.stateAt(2, 2), CellState.edge);
      expect(s.grid.stateAt(4, 4), CellState.claimed);
      expect(s.grid.claimedCount, 9); // the 3x3 inside
    });
  });
}
