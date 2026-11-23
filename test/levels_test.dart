import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_regulus/game/config.dart';
import 'package:project_regulus/game/grid/claim_grid.dart';
import 'package:project_regulus/game/grid/enemy_body.dart';
import 'package:project_regulus/game/grid/events.dart';
import 'package:project_regulus/game/grid/powerups.dart';
import 'package:project_regulus/game/grid/session.dart';
import 'package:project_regulus/game/levels.dart';

void main() {
  final set = LevelSet.zodiac;

  group('the zodiac level set', () {
    test('has twelve distinct signs', () {
      expect(set.length, 12);
      expect(set.children.map((c) => c.sign).toSet().length, 12);
    });

    test('elements follow the wheel: fire, earth, air, water', () {
      const wheel = [
        ElementType.fire,
        ElementType.earth,
        ElementType.air,
        ElementType.water,
      ];
      for (var i = 0; i < 12; i++) {
        expect(set.children[i].element, wheel[i % 4], reason: set.children[i].sign);
      }
    });

    test('every level is playable', () {
      for (final c in set.children) {
        expect(c.captureTarget, inInclusiveRange(0.5, 0.95), reason: c.sign);
        expect(c.enemyCount, greaterThan(0), reason: c.sign);
        expect(c.roster.length, c.enemyCount, reason: c.sign);
        expect(c.enemySpeed, greaterThan(0), reason: c.sign);
      }
    });

    test('it gets harder: the last level has more than the first', () {
      final first = set.children.first;
      final last = set.children.last;
      expect(last.enemyCount, greaterThan(first.enemyCount));
      expect(last.captureTarget, greaterThan(first.captureTarget));
      expect(last.enemySpeed, greaterThan(first.enemySpeed));
    });

    test('a child inherits whatever it does not set from the parent', () {
      final child = set.parent.copyWith(sign: 'Test');
      expect(child.captureTarget, set.parent.captureTarget);
      expect(child.enemies, set.parent.enemies);
    });

    test('levels stop at twelve: nothing past Pisces', () {
      expect(set.forLevel(13).sign, 'Pisces');
      expect(set.forLevel(99).sign, 'Pisces');
      expect(set.forLevel(0).sign, 'Aries');
    });

    test('every level has layers, and later levels have more', () {
      for (final c in set.children) {
        expect(c.layers, greaterThanOrEqualTo(2), reason: c.sign);
      }
      expect(set.children.last.layers, greaterThan(set.children.first.layers));
    });

    test('the roster interleaves kinds instead of grouping them', () {
      const def = LevelDef(
        sign: 'x',
        element: ElementType.fire,
        captureTarget: 0.75,
        enemies: {EnemyKind.bouncer: 2, EnemyKind.snake: 2},
        patrols: 0,
        enemySpeed: 1,
        patrolSpeed: 1,
        respawnSeconds: 3,
        pickupSeconds: 7,
      );
      expect(def.roster, [
        EnemyKind.bouncer,
        EnemyKind.snake,
        EnemyKind.bouncer,
        EnemyKind.snake,
      ]);
    });
  });

  group('the session plays each level by its definition', () {
    test('every level spawns its own enemies, patrols and target', () {
      final s = GameSession(random: Random(3), spawnPickups: false);
      for (var n = 1; n <= set.length; n++) {
        s.startLevel(n);
        final def = set.forLevel(n);
        expect(s.enemies.length, def.enemyCount, reason: def.sign);
        expect(s.patrols.length, def.patrols, reason: def.sign);
        expect(s.grid.captureTarget, def.captureTarget, reason: def.sign);
        expect(s.status, SessionStatus.playing);
      }
    });

    test('the final level fields every kind of enemy', () {
      final s = GameSession(random: Random(1), spawnPickups: false)
        ..startLevel(set.length);
      expect(s.enemies.map((e) => e.kind).toSet(), EnemyKind.values.toSet());
    });

    test('a level is cleared at its own target, not a global one', () {
      final s = GameSession(random: Random(1), spawnPickups: false)
        ..startLevel(1); // Aries: 70%
      expect(s.grid.targetReached, isFalse);
      final regions = s.grid.findEmptyRegions();
      s.grid.claimRegions(regions, (_) => true);
      expect(s.grid.targetReached, isTrue);
    });

    void clear(GameSession s) {
      s.grid.claimRegions(s.grid.findEmptyRegions(), (_) => true);
      s.update(1 / 30, null);
    }

    test('clearing a layer goes down a layer, then on to the next sign', () {
      final s = GameSession(random: Random(1), spawnPickups: false);
      expect((s.def.sign, s.layer, s.layerCount), ('Aries', 1, 2));
      clear(s);
      expect(s.status, SessionStatus.won);
      s.nextLevel();
      expect((s.def.sign, s.layer), ('Aries', 2));
      expect(s.grid.claimedFraction, 0); // a fresh field beneath
      clear(s);
      s.nextLevel();
      expect((s.def.sign, s.layer), ('Taurus', 1));
    });

    test('each deeper layer fields more enemies', () {
      final s = GameSession(random: Random(1), spawnPickups: false)
        ..startLevel(9); // Sagittarius: 4 layers
      final base = s.enemies.length;
      for (var layer = 2; layer <= 4; layer++) {
        clear(s);
        s.nextLevel();
        expect(s.layer, layer);
        expect(s.enemies.length, base + (layer - 1) * GameConfig.enemiesPerLayer);
      }
    });

    test('a layer pays the layer bonus; only a level clear adds a life', () {
      final s = GameSession(random: Random(1), spawnPickups: false);
      clear(s);
      expect(s.levelBonus, GameConfig.layerClearBonus);
      expect(s.events.whereType<LevelCleared>().last.levelDone, isFalse);
      s.nextLevel();
      expect(s.lives, GameConfig.startingLives);
      clear(s);
      expect(s.events.whereType<LevelCleared>().last.levelDone, isTrue);
      s.nextLevel();
      expect(s.lives, GameConfig.startingLives + 1);
    });

    test("the last layer of the last level completes the game", () {
      final s = GameSession(random: Random(1), spawnPickups: false)
        ..startLevel(12, layer: 4);
      clear(s);
      expect(s.status, SessionStatus.complete);
      s.nextLevel(); // nothing to go on to
      expect(s.status, SessionStatus.complete);
      expect(s.level, 12);
    });

    test("the sign's own element turns up most often", () {
      // An empty field, so nothing interrupts; the player stays on the border.
      final s = GameSession(
        random: Random(5),
        levels: set.withCounts(enemies: 0, patrols: 0),
      )..startLevel(2); // Taurus: earth
      var earth = 0;
      const rolls = 150;
      for (var i = 0; i < rolls; i++) {
        s.pickup = null;
        for (var f = 0; f < 400 && s.pickup == null; f++) {
          s.update(1 / 30, null);
        }
        if (s.pickup?.element == ElementType.earth) earth++;
      }
      // 3 of 6 slots are earth, so about half; well above a quarter.
      expect(earth / rolls, greaterThan(0.35));
    });

    test('withCounts overrides enemies and patrols on every level', () {
      final flat = set.withCounts(enemies: 0, patrols: 0);
      for (final c in flat.children) {
        expect(c.enemyCount, 0);
        expect(c.patrols, 0);
      }
      expect(ClaimGrid().captureTarget, greaterThan(0));
    });
  });
}
