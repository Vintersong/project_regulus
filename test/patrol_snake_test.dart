import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_regulus/game/grid/claim_grid.dart';
import 'package:project_regulus/game/grid/enemy_body.dart';
import 'package:project_regulus/game/grid/patrol_body.dart';
import 'package:project_regulus/game/grid/session.dart';

GameSession _session() => GameSession(
      grid: ClaimGrid(columns: 40, rows: 30),
      random: Random(1),
      enemyCount: 0,
      patrolCount: 0,
      spawnPickups: false,
    );

void main() {
  group('PatrolBody', () {
    test('only ever stands on edge cells and keeps moving', () {
      final grid = ClaimGrid(columns: 20, rows: 10);
      final p = PatrolBody(column: 0, row: 0);
      final rng = Random(3);
      final visited = <(int, int)>{};
      for (var t = 0.0; t < 6; t += 1 / 60) {
        p.update(1 / 60, grid, rng, targetColumn: 19, targetRow: 9);
        expect(grid.stateAt(p.column, p.row), CellState.edge);
        visited.add((p.column, p.row));
      }
      expect(visited.length, greaterThan(20));
    });

    test('does not turn straight back along a corridor', () {
      final grid = ClaimGrid(columns: 20, rows: 10);
      final p = PatrolBody(column: 5, row: 0)..place(5, 0);
      final rng = Random(3);
      // Walk one cell at a time (22 cells/s) around the closed rim loop and
      // check it never steps back onto the cell it has just left.
      final path = <(int, int)>[(p.column, p.row)];
      for (var i = 0; i < 120; i++) {
        p.update(1 / 22, grid, rng, targetColumn: 5, targetRow: 9);
        path.add((p.column, p.row));
      }
      for (var i = 2; i < path.length; i++) {
        expect(path[i] == path[i - 2], isFalse,
            reason: 'turned straight back at step $i');
      }
    });

    test('can walk a finished cut and earthquake cracks, not open ground', () {
      final grid = ClaimGrid(columns: 20, rows: 10);
      // A wall of edge cells from the top rim down column 10.
      for (var r = 1; r < 6; r++) {
        grid.setState(10, r, CellState.edge);
      }
      final p = PatrolBody(column: 10, row: 1);
      final rng = Random(5);
      for (var t = 0.0; t < 3; t += 1 / 60) {
        p.update(1 / 60, grid, rng, targetColumn: 10, targetRow: 5);
        expect(grid.stateAt(p.column, p.row), CellState.edge);
      }
    });
  });

  group('GameSession patrols', () {
    test('a spark touching the player costs a life and is sent away', () {
      final s = _session();
      s.patrols.add(PatrolBody(column: 22, row: 29)); // beside the start (20,29)
      s.update(1 / 60, null);
      expect(s.lives, 2);
      final p = s.patrols.single;
      expect(p.row, 0); // back in a far corner
    });

    test('a fresh run parks the sparks in the far corners', () {
      final s = GameSession(
        grid: ClaimGrid(columns: 40, rows: 30),
        random: Random(1),
        enemyCount: 0,
        patrolCount: 2,
        spawnPickups: false,
      );
      expect(s.patrols.length, 2);
      expect(s.patrols.every((p) => p.row == 0), isTrue); // far from bottom start
    });
  });

  group('snake', () {
    EnemyBody snake() => EnemyBody(
          x: 5.5, y: 10.5, vx: 10, vy: 0, kind: EnemyKind.snake, //
        );

    test('starts with a full body trailing behind the head', () {
      final e = snake();
      expect(e.segments.length, 9);
      // Behind the head (heading right), so every segment is to its left.
      expect(e.segments.every((p) => p.x < e.x), isTrue);
    });

    test('body follows the head along its path', () {
      final grid = ClaimGrid(columns: 40, rows: 30);
      final e = snake();
      for (var t = 0.0; t < 1.5; t += 1 / 60) {
        e.update(1 / 60, grid);
      }
      expect(e.x, greaterThan(15));
      expect(e.segments.first.x, lessThan(e.x));
      expect(e.segments.last.x, lessThan(e.segments.first.x));
    });

    test('any body segment inside the line counts as touching it', () {
      final grid = ClaimGrid(columns: 40, rows: 30);
      final e = snake();
      for (var t = 0.0; t < 1.5; t += 1 / 60) {
        e.update(1 / 60, grid);
      }
      expect(e.segmentTouchesTrail(grid), isFalse);
      final seg = e.segments[3];
      grid.setState(seg.x.floor(), seg.y.floor(), CellState.trail);
      expect(e.segmentTouchesTrail(grid), isTrue);
      expect(e.occupiesTrail(grid), isTrue);
    });

    test('distanceTo measures to the nearest body part, not just the head', () {
      final e = snake();
      final tail = e.segments.last;
      expect(e.distanceTo(tail.x, tail.y), closeTo(0, 1e-9));
      expect(e.distanceTo(e.x, e.y), closeTo(0, 1e-9));
    });

    test('a snake wriggles: its heading swings back and forth', () {
      final e = snake();
      final rng = Random(1);
      var lo = double.infinity;
      var hi = -double.infinity;
      for (var t = 0.0; t < 6; t += 1 / 60) {
        e.think(1 / 60, rng);
        lo = min(lo, e.heading);
        hi = max(hi, e.heading);
      }
      expect(hi - lo, greaterThan(0.3));
    });
  });
}
