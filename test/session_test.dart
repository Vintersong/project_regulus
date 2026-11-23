import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_regulus/game/grid/claim_grid.dart';
import 'package:project_regulus/game/grid/direction.dart';
import 'package:project_regulus/game/grid/enemy_body.dart';
import 'package:project_regulus/game/grid/powerups.dart';
import 'package:project_regulus/game/grid/session.dart';

GameSession _session({int columns = 40, int rows = 30}) => GameSession(
      grid: ClaimGrid(columns: columns, rows: rows),
      random: Random(1),
      enemyCount: 0,
      patrolCount: 0, // tests place their own, so none wander in uninvited
      spawnPickups: false,
    );

/// Player cuts 8 cells up column 20: trail on rows 28..21, player at row 21.
void _cutLong(GameSession s) {
  s.walker.reset(20, 29);
  for (var i = 0; i < 8; i++) {
    s.walker.step(Direction.up);
  }
}

/// Advances [seconds] in frame-sized steps (update clamps each frame to 1/30).
void _run(GameSession s, double seconds, [Direction? held]) {
  for (var t = 0.0; t < seconds; t += 1 / 30) {
    s.update(1 / 30, held);
  }
}

/// Crosses the old part of the trail (20, 27) sideways, 6 cells from the
/// player's tip, so only the trail contact can matter, not player contact.
EnemyBody _swiper() => EnemyBody(x: 19.5, y: 27.5, vx: 10, vy: 0);

void main() {
  group('EnemyBody', () {
    test('bounces off the rim', () {
      final grid = ClaimGrid(columns: 10, rows: 8);
      final e = EnemyBody(x: 8.5, y: 3.5, vx: 10, vy: 0);
      e.update(0.1, grid);
      expect(e.vx, -10);
      expect(e.x, lessThan(9)); // never gets into the rim cell
    });

    test('passes through the trail and reports it', () {
      final grid = ClaimGrid(columns: 10, rows: 8)
        ..setState(6, 3, CellState.trail);
      final e = EnemyBody(x: 5.5, y: 3.5, vx: 10, vy: 0);
      expect(e.update(0.1, grid), isTrue);
      expect(e.x, closeTo(6.5, 1e-9));
    });
  });

  group('GameSession', () {
    test('an enemy touching the trail costs a life and wipes the trail', () {
      final s = _session();
      _cutLong(s);
      s.enemies.add(_swiper());
      _run(s, 0.2);
      expect(s.lives, 2);
      expect(s.walker.isDrawing, isFalse);
      expect(s.grid.stateAt(20, 27), CellState.empty);
      expect(s.walker.row, 29); // back at the start
    });

    test('fire kills the enemy instead of the player', () {
      final s = _session();
      _cutLong(s);
      s.effects.activate(ElementType.fire);
      s.enemies.add(_swiper());
      _run(s, 0.2);
      expect(s.lives, 3);
      expect(s.enemies, isEmpty);
      expect(s.walker.isDrawing, isTrue);
    });

    test('water lets the enemy through', () {
      final s = _session();
      _cutLong(s);
      s.effects.activate(ElementType.water);
      s.enemies.add(_swiper());
      _run(s, 0.2);
      expect(s.lives, 3);
      expect(s.enemies.length, 1);
    });

    test('water running out does not kill you for an enemy inside the line', () {
      final s = _session();
      _cutLong(s);
      s.effects.activate(ElementType.water);
      // Parked in the middle of the trail, 6 cells from the player's tip.
      s.enemies.add(EnemyBody(x: 20.5, y: 27.5, vx: 0, vy: 0));
      _run(s, 0.5);
      expect(s.lives, 3); // water is protecting you
      _run(s, 4); // water (3 s) runs out
      expect(s.effects.isActive(ElementType.water), isFalse);
      expect(s.lives, 3); // the line "solidifies": the trapped enemy dies
      expect(s.enemies, isEmpty);
    });

    test('an enemy sealed in captured ground is crushed', () {
      final s = _session(columns: 40, rows: 12);
      // Cut up column 20; left pocket 19 wide, right pocket 18 wide.
      s.walker.reset(20, 11);
      s.enemies
        ..add(EnemyBody(x: 3.5, y: 6.5, vx: 0, vy: 0))
        ..add(EnemyBody(x: 35.5, y: 6.5, vx: 0, vy: 0));
      for (var i = 0; i < 8; i++) {
        s.update(1 / 30, Direction.up);
      }
      expect(s.walker.isDrawing, isFalse);
      // Both pockets held an enemy, so all but the largest (left) is claimed.
      expect(s.enemies.length, 1);
      expect(s.enemies.single.x, lessThan(20));
    });

    test('a pickup is collected by cutting close to it, not only onto it', () {
      final s = _session();
      _cutLong(s); // player mid-cut at (20, 21)
      s.pickup = Pickup(s.grid.index(24, 21), ElementType.water, 10);
      s.update(1 / 30, Direction.up); // steps to row 20, ~4 cells away
      expect(s.pickup, isNull);
      // It goes into the slot; nothing happens until it is used.
      expect(s.held, ElementType.water);
      expect(s.effects.isActive(ElementType.water), isFalse);
      expect(s.useHeld(), isTrue);
      expect(s.held, isNull);
      expect(s.effects.isActive(ElementType.water), isTrue);
    });

    test('a full slot cannot take another pickup', () {
      final s = _session();
      _cutLong(s);
      s.held = ElementType.air;
      s.pickup = Pickup(s.grid.index(24, 21), ElementType.fire, 10);
      s.update(1 / 30, Direction.up);
      expect(s.held, ElementType.air);
      expect(s.pickup, isNotNull);
    });

    test('using an empty slot does nothing', () {
      final s = _session();
      expect(s.useHeld(), isFalse);
    });

    test('a pickup cannot be grabbed from the safe border', () {
      final s = _session();
      s.walker.reset(20, 29);
      s.pickup = Pickup(s.grid.index(23, 27), ElementType.fire, 10);
      s.update(1 / 30, Direction.left); // walks the rim, within 6 cells
      expect(s.pickup, isNotNull);
      expect(s.effects.isActive(ElementType.fire), isFalse);
    });

    test('air makes the player faster', () {
      int distance({required bool air}) {
        final s = _session();
        s.walker.reset(30, 29);
        if (air) s.effects.activate(ElementType.air);
        _run(s, 0.3, Direction.left);
        return 30 - s.walker.column;
      }

      expect(distance(air: true), greaterThan(distance(air: false)));
    });

    test('earth opens cracks mid-cut that wall off and capture ground', () {
      final s = _session();
      _cutLong(s); // mid-cut at (20, 21): open ground ahead and to both sides
      s
        ..held = ElementType.earth
        ..useHeld();

      expect(s.cracks.length, 3); // straight on, left and right
      expect(s.walker.isDrawing, isFalse); // the cut was finished
      expect(s.grid.stateAt(s.walker.column, s.walker.row), CellState.edge);
      // Every crack cell is now border, none left half-open.
      for (final crack in s.cracks) {
        for (final cell in crack.cells) {
          expect(s.grid.stateAtIndex(cell), isNot(CellState.empty));
        }
      }
      // The cracks and the trail split the field, so something got captured.
      expect(s.grid.claimedFraction, greaterThan(0));
    });

    test('earth from the border cracks into the field and does not crash', () {
      final s = _session();
      s.walker.reset(20, 29); // on the bottom rim, not drawing
      s
        ..held = ElementType.earth
        ..useHeld();
      expect(s.cracks, isNotEmpty);
      expect(s.walker.isDrawing, isFalse);
    });

    test('an enemy caught in a crack is crushed', () {
      final s = _session();
      _cutLong(s);
      // Dead ahead of the player, on the straight-on crack's first cells.
      s.enemies.add(EnemyBody(x: 20.5, y: 20.5, vx: 0, vy: 0));
      s
        ..held = ElementType.earth
        ..useHeld();
      expect(s.enemies, isEmpty);
    });

    test('cracks fade away after a while', () {
      final s = _session();
      _cutLong(s);
      s
        ..held = ElementType.earth
        ..useHeld();
      expect(s.cracks, isNotEmpty);
      _run(s, 2);
      expect(s.cracks, isEmpty);
    });

    test('losing every life ends the run, restart brings it back', () {
      final s = _session();
      for (var i = 0; i < 3; i++) {
        _cutLong(s);
        s.enemies
          ..clear()
          ..add(_swiper());
        _run(s, 0.2);
      }
      expect(s.status, SessionStatus.lost);
      s.restart();
      expect(s.status, SessionStatus.playing);
      expect(s.lives, 3);
      expect(s.grid.claimedFraction, 0);
    });
  });
}
