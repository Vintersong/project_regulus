import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_regulus/game/config.dart';
import 'package:project_regulus/game/grid/claim_grid.dart';
import 'package:project_regulus/game/grid/direction.dart';
import 'package:project_regulus/game/grid/enemy_body.dart';
import 'package:project_regulus/game/grid/events.dart';
import 'package:project_regulus/game/grid/powerups.dart';
import 'package:project_regulus/game/grid/session.dart';
import 'package:project_regulus/game/score_store.dart';

GameSession _session() => GameSession(
      grid: ClaimGrid(columns: 40, rows: 30),
      random: Random(1),
      enemyCount: 0,
      patrolCount: 0,
      spawnPickups: false,
    );

void _run(GameSession s, double seconds, [Direction? held]) {
  for (var t = 0.0; t < seconds; t += 1 / 30) {
    s.update(1 / 30, held);
  }
}

/// Cuts straight up from the bottom rim to the top rim at column 20, which
/// splits the field and wins the smaller side.
void _firstCapture(GameSession s) {
  s.walker.reset(20, 29);
  _run(s, 0.7, Direction.up);
}

void main() {
  group('scoring', () {
    test('a capture pays points per cell and reports what it won', () {
      final s = _session();
      _firstCapture(s);
      final captured = s.events.whereType<Captured>().single;
      expect(captured.cells, isNotEmpty);
      expect(captured.combo, 1);
      expect(captured.points, captured.cells.length * GameConfig.pointsPerCell);
      expect(s.score, captured.points);
    });

    test('capturing again in time raises the combo and the pay', () {
      final s = _session();
      _firstCapture(s);
      final first = s.score;
      // Walk the top rim left a bit, then cut straight down the open side.
      _run(s, 0.2, Direction.left);
      _run(s, 1, Direction.down);
      final captures = s.events.whereType<Captured>().toList();
      expect(captures.length, 2);
      expect(captures[1].combo, 2);
      expect(
        captures[1].points,
        captures[1].cells.length * GameConfig.pointsPerCell * 2,
      );
      expect(s.score, greaterThan(first));
    });

    test('the combo lapses if you wait too long', () {
      final s = _session();
      _firstCapture(s);
      s.combo = 3; // as if chained
      _run(s, GameConfig.comboSeconds + 1);
      expect(s.combo, 1);
    });

    test('dying breaks the combo and is reported', () {
      final s = _session();
      _firstCapture(s);
      s.takeEvents();
      s.combo = 4;
      // Column 10 is on the side that is still open ground.
      s.walker.reset(10, 29);
      s.enemies.add(EnemyBody(x: 10.5, y: 28.5, vx: 0, vy: 0));
      s.walker.step(Direction.up); // mid-cut, with an enemy on top of us
      _run(s, 0.1);
      expect(s.combo, 1);
      expect(s.events.whereType<PlayerDied>(), isNotEmpty);
    });

    test('a kill pays and is reported', () {
      final s = _session();
      s.walker.reset(20, 29);
      for (var i = 0; i < 8; i++) {
        s.walker.step(Direction.up);
      }
      s.effects.activate(ElementType.fire);
      s.enemies.add(EnemyBody(x: 19.5, y: 27.5, vx: 10, vy: 0));
      _run(s, 0.2);
      expect(s.score, GameConfig.enemyKillPoints);
      expect(s.events.whereType<EnemyDied>().single.kind, EnemyKind.bouncer);
    });

    test('item use and pickup are reported', () {
      final s = _session();
      _firstCapture(s);
      s.takeEvents();
      s.held = ElementType.air;
      s.useHeld();
      expect(s.events.whereType<ItemUsed>().single.element, ElementType.air);
    });

    test('starting a cut and backing out of it are reported', () {
      final s = _session();
      s.walker.reset(20, 29);
      s.takeEvents();
      s.update(1 / 60, Direction.up); // one step off the border
      final started = s.takeEvents().whereType<CutStarted>().single;
      expect((started.x, started.y), (20.5, 29.5)); // where the cut began

      s.update(1 / 60, Direction.down); // straight back
      expect(s.walker.isDrawing, isFalse);
      expect(s.takeEvents().whereType<CutCancelled>(), isNotEmpty);
    });

    test('without the cut key you cannot leave the border, and are told', () {
      final s = _session()..canStartCut = false;
      s.walker.reset(20, 29);
      s.takeEvents();
      _run(s, 0.5, Direction.up); // pushing into the field for half a second
      expect(s.walker.isDrawing, isFalse);
      expect(s.walker.row, 29); // never left the border
      expect(s.takeEvents().whereType<CutStarted>(), isEmpty);
    });

    test('the refusal is announced once, not every frame', () {
      final s = _session()..canStartCut = false;
      s.walker.reset(20, 29);
      s.takeEvents();
      _run(s, 0.5, Direction.up);
      expect(s.takeEvents().whereType<CutRefused>().length, 1);
    });

    test('holding the cut key lets the same push start a cut', () {
      final s = _session()..canStartCut = true;
      s.walker.reset(20, 29);
      _run(s, 0.1, Direction.up);
      expect(s.walker.isDrawing, isTrue);
    });

    test('walking along the border starts nothing', () {
      final s = _session();
      s.walker.reset(20, 29);
      s.takeEvents();
      _run(s, 0.3, Direction.left);
      expect(s.takeEvents().whereType<CutStarted>(), isEmpty);
    });

    test('takeEvents hands over the events once', () {
      final s = _session();
      _firstCapture(s);
      expect(s.takeEvents(), isNotEmpty);
      expect(s.takeEvents(), isEmpty);
    });
  });

  group('levels', () {
    /// Claims everything open, as if the target were blown past.
    void clearLayer(GameSession s) {
      final regions = s.grid.findEmptyRegions();
      s.grid.claimRegions(regions, (_) => true);
      s.update(1 / 30, null);
    }

    /// Clears every layer of the current level, ending on its final win.
    void clearLevel(GameSession s) {
      clearLayer(s);
      while (!s.isLastLayer) {
        s.nextLevel();
        clearLayer(s);
      }
    }

    test('clearing the last layer wins the level and pays its bonus', () {
      final s = _session();
      clearLevel(s);
      expect(s.status, SessionStatus.won);
      final bonus = GameConfig.levelClearBonus + 3 * GameConfig.lifeBonus;
      expect(s.levelBonus, bonus);
      final layerBonuses = (s.layerCount - 1) * GameConfig.layerClearBonus;
      expect(s.score, bonus + layerBonuses);
      expect(s.events.whereType<LevelCleared>().last.bonus, bonus);
    });

    test('next level keeps the score and adds a life', () {
      final s = _session();
      clearLevel(s);
      final score = s.score;
      s.nextLevel();
      expect(s.status, SessionStatus.playing);
      expect(s.level, 2);
      expect(s.score, score);
      expect(s.lives, 4);
      expect(s.grid.claimedFraction, 0);
    });

    test('lives are capped', () {
      final s = _session();
      for (var i = 0; i < 8; i++) {
        clearLevel(s);
        s.nextLevel();
      }
      expect(s.lives, GameConfig.maxLives);
    });

    test('next level does nothing unless you won', () {
      final s = _session();
      s.nextLevel();
      expect(s.level, 1);
    });

    test('restart wipes the score and the level', () {
      final s = _session();
      clearLevel(s);
      s.nextLevel();
      s.restart();
      expect(s.level, 1);
      expect(s.score, 0);
      expect(s.lives, GameConfig.startingLives);
    });
  });

  group('ScoreStore', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('regulus_score'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('saves and loads a best score', () async {
      final store = ScoreStore(path: '${dir.path}/sub/best.txt');
      expect(await store.load(), 0); // nothing saved yet
      await store.save(12345);
      expect(await store.load(), 12345);
    });

    test('a corrupt file reads as zero instead of throwing', () async {
      final path = '${dir.path}/best.txt';
      File(path).writeAsStringSync('not a number');
      expect(await ScoreStore(path: path).load(), 0);
    });
  });
}
