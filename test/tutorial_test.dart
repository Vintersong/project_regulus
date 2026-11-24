import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_regulus/game/grid/claim_grid.dart';
import 'package:project_regulus/game/grid/direction.dart';
import 'package:project_regulus/game/grid/session.dart';
import 'package:project_regulus/game/tutorial.dart';

void main() {
  late GameSession s;
  late Tutorial t;

  setUp(() {
    s = GameSession(
      grid: ClaimGrid(columns: 60, rows: 40),
      random: Random(1),
      spawnDrops: true, // the tutorial must still not bury random ones
    );
    t = Tutorial(s)..start();
  });

  /// One frame as the game runs it: rules, then the tutorial watching this
  /// frame's events, then the events drained (as the effects layer does).
  void frame({Direction? held, bool cut = false}) {
    s.canStartCut = cut;
    s.update(1 / 60, held);
    t.update();
    s.takeEvents();
  }

  void frames(int n, {Direction? held, bool cut = false}) {
    for (var i = 0; i < n; i++) {
      frame(held: held, cut: cut);
    }
  }

  void claimEverything() =>
      s.grid.claimRegions(s.grid.findEmptyRegions(), (_) => true);

  test('starts on a clean, enemy-free tutorial field', () {
    expect(s.tutorial, isTrue);
    expect(s.enemies, isEmpty);
    expect(s.patrols, isEmpty);
    expect(s.drops, isEmpty);
    expect(s.layerCount, 2);
    expect(t.index, 0);
  });

  test('walks through every step to a real run', () {
    // 0: move along the border.
    frames(25, held: Direction.left);
    expect(t.index, 1);

    // 1: hold the cut key and step in.
    frame(held: Direction.up, cut: true);
    expect(t.index, 2);

    // 2: step straight back to undo it.
    frame(held: Direction.down);
    expect(t.index, 3);
    expect(s.walker.isDrawing, isFalse);

    // 3: cut right across the field to the far rim.
    frames(45, held: Direction.up, cut: true);
    expect(t.index, 4);
    expect(s.grid.claimedCount, greaterThan(0));

    // 4: an element was placed; collecting it is what matters here.
    expect(s.pickup, isNotNull);
    s
      ..held = s.pickup!.element
      ..pickup = null;
    frame();
    expect(t.index, 5);

    // 5: use it.
    s.useHeld();
    frame();
    expect(t.index, 6);

    // 6: a drop was placed, and the tutorial's drop is always a good one.
    expect(s.drops, hasLength(1));
    expect(s.dropGoodChance, 1);
    claimEverything(); // covers the drop; collected on the next step taken
    // Past the target already, but the layer is held until it is taught.
    frame(held: Direction.left);
    frame(held: Direction.right);
    expect(t.index, 7);

    // 7: now clearing the layer is allowed.
    frame();
    expect(s.status, SessionStatus.won);
    expect(t.index, 8);

    // 8: layer 2, and its own win (layer 1's banner alone doesn't count).
    frames(3);
    expect(t.index, 8);
    s.nextLevel();
    expect(s.layer, 2);
    claimEverything();
    frame();
    expect(t.finished, isTrue);

    // Done: Space starts the real game at Aries.
    s.nextLevel();
    expect(s.tutorial, isFalse);
    expect((s.level, s.layer, s.def.sign), (1, 1, 'Aries'));
    expect(s.dropGoodChance, lessThan(1));
  });

  test('a capture that swallows the orb puts a new one out', () {
    frames(25, held: Direction.left);
    frame(held: Direction.up, cut: true);
    frame(held: Direction.down);
    frames(45, held: Direction.up, cut: true);
    expect(t.index, 4);
    // A capture swallows the orb's cell (the rest of the field stays open).
    final first = s.pickup!.cell;
    s.grid.setStateAtIndex(first, CellState.claimed);
    frame(held: Direction.left); // a step: the swallowed orb is dropped...
    frame(); // ...and the tutorial puts a new one out
    expect(s.pickup, isNotNull);
    expect(s.pickup!.cell, isNot(first));
    expect(s.grid.stateAtIndex(s.pickup!.cell), CellState.empty);
    expect(t.index, 4);
  });
}
