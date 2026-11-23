import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_regulus/game/config.dart';
import 'package:project_regulus/game/levels.dart';
import 'package:project_regulus/game/grid/claim_grid.dart';
import 'package:project_regulus/game/grid/enemy_body.dart';
import 'package:project_regulus/game/grid/session.dart';

double _speed(EnemyBody e) => sqrt(e.vx * e.vx + e.vy * e.vy);

void main() {
  group('hunter', () {
    test('turns toward the player but keeps its speed', () {
      final e = EnemyBody(
        x: 10.5, y: 10.5, vx: 10, vy: 0, kind: EnemyKind.hunter, //
      );
      // Player straight "up" (negative y) from a right-heading hunter.
      e.think(0.5, Random(1), targetX: 10.5, targetY: 2.5);
      expect(e.vy, lessThan(0));
      expect(_speed(e), closeTo(10, 1e-9));
    });

    test('turn rate is limited, so it can be dodged', () {
      final e = EnemyBody(
        x: 10.5, y: 10.5, vx: 10, vy: 0, kind: EnemyKind.hunter, //
      );
      e.think(0.1, Random(1), targetX: 0.5, targetY: 10.5); // dead behind it
      // 0.1 s at the turn rate is a small nudge, nowhere near a U-turn.
      expect(e.heading.abs(), closeTo(GameConfig.hunterTurnRate * 0.1, 1e-9));
    });

    test('keeps its heading when there is nothing to hunt', () {
      final e = EnemyBody(
        x: 10.5, y: 10.5, vx: 10, vy: 0, kind: EnemyKind.hunter, //
      );
      e.think(1, Random(1));
      expect(e.vx, 10);
      expect(e.vy, 0);
    });
  });

  group('dasher', () {
    test('creeps, then bursts well above its cruising speed', () {
      final e = EnemyBody(
        x: 10.5, y: 10.5, vx: 8, vy: 0, kind: EnemyKind.dasher, //
      );
      final rng = Random(1);
      var fastest = 0.0;
      var slowest = double.infinity;
      for (var t = 0.0; t < 6; t += 1 / 60) {
        e.think(1 / 60, rng);
        fastest = max(fastest, _speed(e));
        slowest = min(slowest, _speed(e));
      }
      expect(slowest, closeTo(8, 1e-9));
      expect(fastest, closeTo(8 * GameConfig.dashSpeedScale, 1e-9));
    });
  });

  group('drifter', () {
    test('keeps changing heading at a steady speed', () {
      final e = EnemyBody(
        x: 10.5, y: 10.5, vx: 10, vy: 0, kind: EnemyKind.drifter, //
      );
      final rng = Random(1);
      final headings = <double>{};
      for (var t = 0.0; t < 4; t += 1 / 60) {
        e.think(1 / 60, rng);
        headings.add(double.parse(e.heading.toStringAsFixed(3)));
        expect(_speed(e), closeTo(10, 1e-9));
      }
      expect(headings.length, greaterThan(3));
    });
  });

  group('movement', () {
    test('a fast enemy cannot tunnel through a one-cell trail', () {
      final grid = ClaimGrid(columns: 20, rows: 10)
        ..setState(6, 5, CellState.trail);
      // 80 cells/s for a 1/30 s frame is 2.7 cells: more than the trail is thick.
      final e = EnemyBody(x: 4.5, y: 5.5, vx: 80, vy: 0);
      expect(e.update(1 / 30, grid), isTrue);
    });
  });

  group('GameSession spawns', () {
    test('the final level fields every kind of enemy', () {
      final s = GameSession(random: Random(1), spawnPickups: false)
        ..startLevel(LevelSet.zodiac.length);
      expect(s.enemies.length, s.def.enemyCount);
      expect(s.enemies.map((e) => e.kind).toSet(), EnemyKind.values.toSet());
    });
  });
}
