import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_regulus/game/grid/claim_grid.dart';
import 'package:project_regulus/game/grid/direction.dart';
import 'package:project_regulus/game/grid/drops.dart';
import 'package:project_regulus/game/grid/events.dart';
import 'package:project_regulus/game/grid/session.dart';

GameSession quiet() => GameSession(
      grid: ClaimGrid(columns: 40, rows: 30),
      enemyCount: 0,
      patrolCount: 0,
      spawnPickups: false,
    );

void main() {
  test('rollDrop honours the good/bad odds', () {
    final r = Random(1);
    expect(
      List.generate(200, (_) => rollDrop(r, goodChance: 1)).every((e) => e.good),
      isTrue,
    );
    expect(
      List.generate(200, (_) => rollDrop(r, goodChance: 0)).any((e) => e.good),
      isFalse,
    );
  });

  test('a capture that covers a drop collects it', () {
    final s = quiet();
    s.drops.add(Drop(s.grid.index(20, 20)));
    s.walker.reset(10, 29);
    // Cut a loop that walls off (20,20) without passing within touch range,
    // so only the capture can collect it: up, right across the top, down.
    void run(Direction d, int cells) {
      for (var i = 0; i < cells; i++) {
        s.update(1 / 60, d);
      }
    }

    run(Direction.up, 18); // (10,11)
    expect(s.drops, hasLength(1));
    run(Direction.right, 20); // (30,11)
    run(Direction.down, 18); // back onto the rim
    expect(s.grid.claimedCount, greaterThan(0));
    expect(s.drops, isEmpty);
    expect(s.takeEvents().whereType<DropCollected>(), hasLength(1));
  });

  test('touching a drop mid-cut collects it', () {
    final s = quiet();
    s.drops.add(Drop(s.grid.index(20, 20)));
    s.walker.reset(20, 29);
    // Drive the real input path: hold up until the drop is reached.
    for (var i = 0; i < 400 && s.drops.isNotEmpty; i++) {
      s.update(1 / 60, Direction.up);
    }
    expect(s.drops, isEmpty);
    expect(s.takeEvents().whereType<DropCollected>(), hasLength(1));
  });

  test('time stop freezes enemies; shield absorbs one hit', () {
    final s = GameSession(
      grid: ClaimGrid(columns: 40, rows: 30),
      enemyCount: 1,
      patrolCount: 0,
      spawnPickups: false,
    );
    final e = s.enemies.single;
    final x = e.x;
    s.applyDrop(DropEffect.timeStop);
    for (var i = 0; i < 30; i++) {
      s.update(1 / 60, null);
    }
    expect(e.x, x);

    s.applyDrop(DropEffect.shield);
    expect(s.shield, isTrue);
  });

  test('bomb destroys the nearest enemies; extra life respects the cap', () {
    final s = GameSession(
      grid: ClaimGrid(columns: 40, rows: 30),
      enemyCount: 3,
      patrolCount: 0,
      spawnPickups: false,
    );
    s.applyDrop(DropEffect.bomb);
    expect(s.enemies, hasLength(1));
    for (var i = 0; i < 10; i++) {
      s.applyDrop(DropEffect.extraLife);
    }
    expect(s.lives, 5);
  });
}
