import 'dart:math';

import '../config.dart';
import '../levels.dart';
import 'claim_grid.dart';
import 'direction.dart';
import 'drops.dart';
import 'enemy_body.dart';
import 'events.dart';
import 'patrol_body.dart';
import 'powerups.dart';
import 'walker.dart';

enum SessionStatus {
  playing,

  /// A layer or a level was cleared; [GameSession.nextLevel] goes on.
  won,
  lost,

  /// The last layer of the last level is cleared: the game is beaten.
  complete,
}

/// All the rules of one level, with no Flame in it: the grid, the player,
/// enemies, lives, elemental effects and pickups. Components only draw this.
class GameSession {
  GameSession({
    ClaimGrid? grid,
    Random? random,
    LevelSet? levels,
    // Tests: force the enemy / patrol counts on every level.
    int? enemyCount,
    int? patrolCount,
    this.spawnPickups = true,
    this.spawnDrops = false,
  })  : grid = grid ?? ClaimGrid(),
        random = random ?? Random(),
        levels = (enemyCount == null && patrolCount == null)
            ? (levels ?? LevelSet.zodiac)
            : (levels ?? LevelSet.zodiac)
                .withCounts(enemies: enemyCount, patrols: patrolCount) {
    restart();
  }

  final ClaimGrid grid;
  final Random random;

  /// The parent level and its twelve children.
  final LevelSet levels;

  /// The rules of the level being played.
  LevelDef get def => tutorial ? LevelSet.tutorialLevel : levels.forLevel(level);

  /// Whether this is the tutorial's field rather than a zodiac level.
  bool tutorial = false;

  /// While true, reaching the target does not clear the layer yet. The
  /// tutorial holds it until it has taught everything before that step.
  bool holdWin = false;

  /// Odds a mystery drop helps. The tutorial sets 1, so its drop is kind.
  double dropGoodChance = GameConfig.dropGoodChance;

  /// How many enemies this layer keeps on the field: the level's own, plus
  /// more on each deeper layer.
  int get enemyCount => def.enemyCount == 0
      ? 0
      : def.enemyCount + (layer - 1) * GameConfig.enemiesPerLayer;

  /// Which of the level's stacked fields is being played (1-based).
  int layer = 1;
  int get layerCount => def.layers;
  bool get isLastLayer => layer >= layerCount;

  /// How many levels there are; the game ends after the last.
  int get levelCount => levels.length;

  /// How many border patrols run the edge.
  int get patrolCount => def.patrols;

  int level = 1;
  int score = 0;

  /// Score multiplier from chained captures, and the seconds left to chain.
  int combo = 1;
  double _comboTimer = 0;
  double get comboTimeLeft => _comboTimer;

  /// What the last level clear paid, for the banner.
  int levelBonus = 0;

  /// Whether the player may start a cut right now: true while the cut key is
  /// held. The game sets it every frame from the keyboard; it defaults to
  /// true so the rules can be driven without a keyboard.
  bool canStartCut = true;
  double _refusedCooldown = 0;

  /// What just happened, for the effects layer. Drain with [takeEvents].
  final List<GameEvent> events = [];

  /// Returns and clears everything that happened since the last call.
  List<GameEvent> takeEvents() {
    final out = List<GameEvent>.of(events);
    events.clear();
    return out;
  }

  final bool spawnPickups;

  /// Whether mystery drops are buried at the start of a level. The game turns
  /// it on; tests leave it off, or place their own in [drops].
  final bool spawnDrops;

  /// Mystery drops still waiting in the ground.
  final List<Drop> drops = [];

  /// Timed effects from drops, and the shield.
  final DropTimers dropEffects = DropTimers();
  bool shield = false;
  double _graceTime = 0;

  /// Sparks on the edge. Public so tests can place one.
  final List<PatrolBody> patrols = [];

  late final Walker walker = Walker(grid, column: _startColumn, row: _startRow);
  final List<EnemyBody> enemies = [];
  final ActiveEffects effects = ActiveEffects();

  /// The element waiting in the field, if any. Public so tests can place one.
  Pickup? pickup;

  /// The single held item (like a Mario Kart slot). Picked up from the field,
  /// fired with [useHeld]. Public so dev shortcuts and tests can fill it.
  ElementType? held;

  /// Recent earthquake cracks, kept just long enough to draw them.
  final List<Crack> cracks = [];

  int lives = GameConfig.startingLives;
  SessionStatus status = SessionStatus.playing;

  int _spawned = 0; // enemies spawned this run, to cycle through the kinds
  bool _waterWasActive = false;
  double _stepAccumulator = 0;
  double _pickupTimer = 0; // set by _resetField
  double _enemyTimer = 0; // set by _resetField

  int get _startColumn => grid.columns ~/ 2;
  int get _startRow => grid.rows - 1;

  /// A brand new run: level 1, no score, full lives.
  void restart() {
    tutorial = false;
    holdWin = false;
    dropGoodChance = GameConfig.dropGoodChance;
    level = 1;
    layer = 1;
    score = 0;
    combo = 1;
    _comboTimer = 0;
    lives = GameConfig.startingLives;
    _resetField();
  }

  /// The tutorial's field, from the start. Finishing it (its last layer, then
  /// [nextLevel]) starts a fresh run at level 1.
  void startTutorial() {
    restart();
    tutorial = true;
    _resetField();
  }

  /// After a win: down to the next layer of this level, or, after its last
  /// layer, on to the next level (with a spare life). The score carries over.
  void nextLevel() {
    if (status != SessionStatus.won) return;
    if (tutorial && isLastLayer) {
      restart(); // tutorial done: the real game begins
      return;
    }
    if (!isLastLayer) {
      layer++;
    } else {
      level++;
      layer = 1;
      lives = min(lives + 1, GameConfig.maxLives);
    }
    _resetField();
  }

  /// Jumps straight to level [n] (1-based) with a fresh field. For level
  /// select, debugging and tests; score and lives are left as they are.
  void startLevel(int n, {int layer = 1}) {
    level = n.clamp(1, levelCount);
    this.layer = layer.clamp(1, def.layers);
    _resetField();
  }

  /// A fresh field for the current level.
  void _resetField() {
    grid.reset();
    walker.reset(_startColumn, _startRow);
    enemies.clear();
    effects.clear();
    cracks.clear();
    pickup = null;
    held = null;
    dropEffects.clear();
    shield = false;
    _graceTime = 0;
    drops.clear();
    if (spawnDrops && !tutorial) _buryDrops();
    _spawned = 0;
    _waterWasActive = false;
    _refusedCooldown = 0;
    patrols
      ..clear()
      ..addAll([
        for (var i = 0; i < patrolCount; i++) PatrolBody(column: 0, row: 0),
      ]);
    _placePatrols();
    status = SessionStatus.playing;
    _stepAccumulator = 0;
    grid.captureTarget = def.captureTarget;
    _pickupTimer = def.pickupSeconds;
    _enemyTimer = def.respawnSeconds;
    for (var i = 0; i < enemyCount; i++) {
      _spawnEnemy();
    }
  }

  /// Advances the level by [dt] seconds. [held] is the direction the player
  /// is holding, or null.
  void update(double dt, Direction? held) {
    if (status != SessionStatus.playing) return;
    dt = min(dt, 1 / 30); // a long frame must not teleport anything

    effects.tick(dt);
    dropEffects.tick(dt);
    if (_graceTime > 0) _graceTime -= dt;

    if (_refusedCooldown > 0) _refusedCooldown -= dt;

    // The combo lapses if you don't capture again in time.
    if (_comboTimer > 0) {
      _comboTimer -= dt;
      if (_comboTimer <= 0) combo = 1;
    }

    // When water runs out, the line turns solid again. Anything caught inside
    // it is destroyed, instead of the line killing you for it next frame.
    final water = effects.isActive(ElementType.water);
    if (_waterWasActive && !water) {
      _killEnemiesWhere((e) => e.occupiesTrail(grid));
    }
    _waterWasActive = water;

    for (final crack in cracks) {
      crack.age += dt;
    }
    cracks.removeWhere((c) => c.age > GameConfig.crackSeconds);
    _movePlayer(dt, held);
    if (status != SessionStatus.playing) return;
    // Time stop freezes everything hostile, and makes it harmless too.
    if (!dropEffects.isActive(DropEffect.timeStop)) {
      _moveEnemies(dt);
      if (status != SessionStatus.playing) return;
      _movePatrols(dt);
      if (status != SessionStatus.playing) return;
    }
    _updatePickup(dt);
    _respawnEnemies(dt);
    if (grid.targetReached && !holdWin) _winLevel();
  }

  /// Dev only: claims a block of ground with a border around it, so effects
  /// that need captured ground can be looked at without playing for it.
  void debugClaimRect(int c0, int r0, int c1, int r1) {
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        if (!grid.inBounds(c, r) || grid.stateAt(c, r) != CellState.empty) {
          continue;
        }
        final border = c == c0 || c == c1 || r == r0 || r == r1;
        grid.setState(c, r, border ? CellState.edge : CellState.claimed);
      }
    }
  }

  // --- score --------------------------------------------------------------

  /// Pays for ground just won. Capturing again before the combo lapses
  /// raises the multiplier.
  void _awardCapture(int cells) {
    if (cells <= 0) return;
    combo = _comboTimer > 0 ? min(combo + 1, GameConfig.maxCombo) : 1;
    _comboTimer = GameConfig.comboSeconds;
    final points = cells * GameConfig.pointsPerCell * combo;
    score += points;

    // The middle of what was just won, for effects to burst from.
    final won = walker.lastClaimed;
    var sx = 0.0;
    var sy = 0.0;
    for (final i in won) {
      sx += grid.columnOf(i);
      sy += grid.rowOf(i);
    }
    events.add(
      Captured(
        cells: List.of(won),
        points: points,
        combo: combo,
        x: won.isEmpty ? walker.column + 0.5 : sx / won.length + 0.5,
        y: won.isEmpty ? walker.row + 0.5 : sy / won.length + 0.5,
      ),
    );
  }

  void _killEnemy(EnemyBody e) {
    if (!enemies.remove(e)) return;
    score += GameConfig.enemyKillPoints;
    events.add(EnemyDied(e.x, e.y, e.kind));
  }

  void _killEnemiesWhere(bool Function(EnemyBody e) test) {
    for (final e in enemies.where(test).toList()) {
      _killEnemy(e);
    }
  }

  void _winLevel() {
    if (!isLastLayer) {
      // A layer down, more beneath: a smaller bonus, and no life.
      status = SessionStatus.won;
      levelBonus = GameConfig.layerClearBonus;
      score += levelBonus;
      events.add(LevelCleared(levelBonus, levelDone: false));
      return;
    }
    status = level >= levelCount ? SessionStatus.complete : SessionStatus.won;
    levelBonus = GameConfig.levelClearBonus + lives * GameConfig.lifeBonus;
    score += levelBonus;
    events.add(LevelCleared(levelBonus));
  }

  // --- player -------------------------------------------------------------

  void _movePlayer(double dt, Direction? held) {
    if (held == null) {
      _stepAccumulator = 0;
      return;
    }
    final scale = (effects.isActive(ElementType.air)
            ? GameConfig.airPlayerSpeedScale
            : 1.0) *
        (dropEffects.isActive(DropEffect.sluggish)
            ? GameConfig.sluggishPlayerScale
            : 1.0);
    final stepTime = 1 / (GameConfig.playerCellsPerSecond * scale);

    _stepAccumulator += dt;
    while (_stepAccumulator >= stepTime) {
      _stepAccumulator -= stepTime;
      final before = grid.claimedCount;
      final wasCutting = walker.isDrawing;
      final result = walker.step(
        held,
        enemyCells: _enemyCells(),
        canStartCut: canStartCut,
        latchCells: GameConfig.latchCells,
      );
      if (result == StepResult.cutRefused) {
        // Pushing toward open ground without the cut key. Say so, but not
        // every frame the direction is held.
        if (_refusedCooldown <= 0) {
          events.add(CutRefused(walker.column + 0.5, walker.row + 0.5));
          _refusedCooldown = 1.2;
        }
        _stepAccumulator = 0;
        break;
      }
      if (result == StepResult.blocked) {
        _stepAccumulator = 0; // don't bank steps while pushing on a wall
        break;
      }
      // Tell the effects when you commit to a cut, and when you back out.
      if (!wasCutting && walker.isDrawing) {
        events.add(CutStarted(walker.edgeColumn + 0.5, walker.edgeRow + 0.5));
      } else if (wasCutting && !walker.isDrawing && result == StepResult.retracted) {
        events.add(CutCancelled(walker.column + 0.5, walker.row + 0.5));
      }
      _afterStep(result, captured: grid.claimedCount - before);
    }
  }

  void _afterStep(StepResult result, {int captured = 0}) {
    if (result == StepResult.closedTrail) {
      _awardCapture(captured);
      // Enemies caught on ground that was just captured are crushed.
      _killEnemiesWhere((e) {
        final s = grid.stateAt(e.column, e.row);
        return s != CellState.empty && s != CellState.trail;
      });
    }

    _collectDrops();

    final p = pickup;
    if (p == null) return;
    // Collected by reaching it, or by cutting close enough that the drawn dot
    // overlaps it. It has to be mid-cut: no grabbing from the safe border.
    final dx = grid.columnOf(p.cell) - walker.column;
    final dy = grid.rowOf(p.cell) - walker.row;
    final close =
        sqrt(dx * dx + dy * dy) < GameConfig.pickupCollectRadiusCells;
    final reached = walker.index == p.cell || (walker.isDrawing && close);

    // One item at a time, like Mario Kart: a full slot can't take another.
    if (reached && held == null) {
      pickup = null;
      held = p.element;
      events.add(
        PickedUp(p.element, grid.columnOf(p.cell) + 0.5, grid.rowOf(p.cell) + 0.5),
      );
      return;
    }
    // Otherwise it stays put, unless a trail or capture just covered it.
    if (grid.stateAtIndex(p.cell) != CellState.empty) pickup = null;
  }

  /// Fires the held item, if any. Works any time: mid-cut, on the border.
  /// Returns whether something was used.
  bool useHeld() {
    final type = held;
    if (type == null || status != SessionStatus.playing) return false;
    held = null;
    events.add(ItemUsed(type, walker.column + 0.5, walker.row + 0.5));
    _apply(type);
    return true;
  }

  void _apply(ElementType type) {
    if (type == ElementType.earth) {
      _earthquake();
    } else {
      effects.activate(type);
    }
  }

  /// Earth: a crack runs out of the player in every direction that is open.
  /// Mid-cut that is three ways (straight on and both sides); on the border,
  /// into the field. Each crack becomes border, so together with the open
  /// trail they wall off pockets, which the capture rule then decides.
  void _earthquake() {
    final fresh = <Crack>[];
    for (final heading in Direction.values) {
      if (!_isOpen(walker.column + heading.dc, walker.row + heading.dr)) {
        continue;
      }
      final cells = _crackFrom(walker.column, walker.row, heading);
      if (cells.isNotEmpty) fresh.add(Crack(cells));
    }
    if (fresh.isEmpty) return;

    cracks.addAll(fresh);
    final before = grid.claimedCount;
    walker.shatter(
      {for (final c in fresh) ...c.cells},
      enemyCells: _enemyCells(),
    );
    // Pay for the ground, crush enemies, clear the pickup.
    _afterStep(StepResult.closedTrail, captured: grid.claimedCount - before);
  }

  bool _isOpen(int column, int row) =>
      grid.inBounds(column, row) &&
      grid.stateAt(column, row) == CellState.empty;

  /// A jagged path through open ground from ([column], [row]) heading
  /// [heading], ending where it meets border, claimed ground or the trail.
  List<int> _crackFrom(int column, int row, Direction heading) {
    // The two sideways directions, for lurching off-line.
    final sideways = heading.dc == 0
        ? const [Direction.left, Direction.right]
        : const [Direction.up, Direction.down];
    final cells = <int>[];
    var c = column;
    var r = row;
    for (var i = 0; i < grid.columns + grid.rows; i++) {
      var step = random.nextDouble() < GameConfig.crackJitter
          ? sideways[random.nextInt(2)]
          : heading;
      if (!_isOpen(c + step.dc, r + step.dr)) step = heading; // blocked: go on
      if (!_isOpen(c + step.dc, r + step.dr)) break; // wall: the crack is done
      c += step.dc;
      r += step.dr;
      cells.add(grid.index(c, r));
    }
    return cells;
  }

  void _loseLife() {
    // A shield eats one hit, then a moment of grace so the same touch (an
    // enemy sitting on your line) does not count twice.
    if (_graceTime > 0) return;
    if (shield) {
      shield = false;
      _graceTime = GameConfig.shieldGraceSeconds;
      events.add(ShieldBroke(walker.column + 0.5, walker.row + 0.5));
      return;
    }
    events.add(PlayerDied(walker.column + 0.5, walker.row + 0.5));
    combo = 1; // dying breaks the chain
    _comboTimer = 0;
    lives--;
    walker.abortTrail();
    walker.reset(_startColumn, _startRow);
    _placePatrols();
    _stepAccumulator = 0;
    if (lives <= 0) status = SessionStatus.lost;
  }

  // --- enemies ------------------------------------------------------------

  Set<int> _enemyCells() => {
        for (final e in enemies)
          if (grid.inBounds(e.column, e.row)) grid.index(e.column, e.row),
      };

  void _moveEnemies(double dt) {
    final scale = def.enemySpeed * _hostileScale;

    for (final e in List.of(enemies)) {
      // Hunters only hunt while the player is out in the open, cutting.
      e.think(
        dt,
        random,
        targetX: walker.isDrawing ? walker.column + 0.5 : null,
        targetY: walker.isDrawing ? walker.row + 0.5 : null,
      );
      // A snake's body counts too: any part in the line is a touch.
      final touchedTrail =
          e.update(dt, grid, speedScale: scale) || e.segmentTouchesTrail(grid);

      if (touchedTrail && !effects.isActive(ElementType.water)) {
        if (effects.isActive(ElementType.fire)) {
          _killEnemy(e); // the burning line kills it
          continue;
        }
        _loseLife();
        return;
      }

      // Touching the player while mid-cut is a hit too (water doesn't help).
      if (walker.isDrawing &&
          e.distanceTo(walker.column + 0.5, walker.row + 0.5) <
              GameConfig.contactRadiusCells) {
        _loseLife();
        return;
      }
    }
  }

  /// Speed multiplier on everything hostile: slow and rush stack. (Air only
  /// speeds the player up.)
  double get _hostileScale =>
      (dropEffects.isActive(DropEffect.slow) ? GameConfig.slowEnemyScale : 1.0) *
      (dropEffects.isActive(DropEffect.rush) ? GameConfig.rushEnemyScale : 1.0);

  // --- border patrols -----------------------------------------------------

  void _movePatrols(double dt) {
    final scale = def.patrolSpeed * _hostileScale;
    for (final p in patrols) {
      p.update(
        dt,
        grid,
        random,
        targetColumn: walker.column,
        targetRow: walker.row,
        speedScale: scale,
      );
      final dx = p.column - walker.column;
      final dy = p.row - walker.row;
      if (sqrt(dx * dx + dy * dy) < GameConfig.patrolContactRadiusCells) {
        _loseLife();
        return;
      }
    }
  }

  /// Parks the patrols in the corners farthest from where the player starts,
  /// so a respawn is never an instant hit.
  void _placePatrols() {
    final corners = [
      (0, 0),
      (grid.columns - 1, 0),
      (0, grid.rows - 1),
      (grid.columns - 1, grid.rows - 1),
    ];
    double far((int, int) c) {
      final dx = c.$1 - _startColumn;
      final dy = c.$2 - _startRow;
      return sqrt(dx * dx + dy * dy);
    }

    corners.sort((a, b) => far(b).compareTo(far(a)));
    for (var i = 0; i < patrols.length; i++) {
      final c = corners[i % corners.length];
      patrols[i].place(c.$1, c.$2);
    }
  }

  void _respawnEnemies(double dt) {
    if (enemies.length >= enemyCount) return;
    _enemyTimer -= dt;
    if (_enemyTimer > 0) return;
    _enemyTimer = def.respawnSeconds;
    _spawnEnemy();
  }

  void _spawnEnemy() {
    final cell = _randomEmptyCell(minDistanceFromPlayer: 20);
    if (cell == null) return;
    // Cycle through the kinds so the field is always a mix.
    final roster = def.roster;
    if (roster.isEmpty) return;
    final kind = roster[_spawned++ % roster.length];
    // A diagonal-ish heading, never axis-aligned, so it sweeps the field.
    final angle = (20 + random.nextDouble() * 50) * pi / 180;
    final speed = GameConfig.enemyCellsPerSecond * kind.speedFactor;
    enemies.add(
      EnemyBody(
        x: grid.columnOf(cell) + 0.5,
        y: grid.rowOf(cell) + 0.5,
        vx: cos(angle) * speed * (random.nextBool() ? 1 : -1),
        vy: sin(angle) * speed * (random.nextBool() ? 1 : -1),
        kind: kind,
      ),
    );
  }

  // --- pickups ------------------------------------------------------------

  void _updatePickup(double dt) {
    if (!spawnPickups) return;
    final p = pickup;
    if (p != null) {
      p.timeLeft -= dt;
      if (p.timeLeft <= 0) {
        pickup = null;
        _pickupTimer = def.pickupSeconds;
      }
      return;
    }
    _pickupTimer -= dt;
    if (_pickupTimer > 0) return;
    _pickupTimer = def.pickupSeconds;

    final cell = _randomEmptyCell(minDistanceFromPlayer: 10);
    if (cell == null) return;
    // The sign's own element is three times as likely as each of the others.
    final bag = [
      for (final e in ElementType.values) ...List.filled(e == def.element ? 3 : 1, e),
    ];
    final element = bag[random.nextInt(bag.length)];
    pickup = Pickup(cell, element, GameConfig.pickupLifetimeSeconds);
  }

  // --- mystery drops ------------------------------------------------------

  void _buryDrops() {
    for (var i = 0; i < GameConfig.dropsPerLevel; i++) {
      final cell = _randomEmptyCell(minDistanceFromPlayer: 25);
      if (cell != null && drops.every((d) => d.cell != cell)) {
        drops.add(Drop(cell));
      }
    }
  }

  /// A drop is collected when a capture (or the trail) covers its cell, or
  /// when the player touches it mid-cut. The border is no place to grab one.
  void _collectDrops() {
    for (final d in List.of(drops)) {
      final covered = grid.stateAtIndex(d.cell) != CellState.empty;
      final dx = grid.columnOf(d.cell) - walker.column;
      final dy = grid.rowOf(d.cell) - walker.row;
      final touched = walker.isDrawing &&
          sqrt(dx * dx + dy * dy) < GameConfig.dropCollectRadiusCells;
      if (!covered && !touched) continue;
      drops.remove(d);
      final effect = rollDrop(random, goodChance: dropGoodChance);
      events.add(
        DropCollected(
          effect,
          grid.columnOf(d.cell) + 0.5,
          grid.rowOf(d.cell) + 0.5,
        ),
      );
      _applyDrop(effect);
    }
  }

  /// Applies [effect] right now. Public so tests can try each one.
  void applyDrop(DropEffect effect) => _applyDrop(effect);

  void _applyDrop(DropEffect effect) {
    switch (effect) {
      case DropEffect.timeStop:
      case DropEffect.slow:
      case DropEffect.rush:
      case DropEffect.sluggish:
        dropEffects.activate(effect);
      case DropEffect.shield:
        shield = true;
      case DropEffect.extraLife:
        lives = min(lives + 1, GameConfig.maxLives);
      case DropEffect.jackpot:
        score += GameConfig.jackpotPoints;
      case DropEffect.bomb:
        final px = walker.column + 0.5;
        final py = walker.row + 0.5;
        final nearest = List.of(enemies)
          ..sort((a, b) => a.distanceTo(px, py).compareTo(b.distanceTo(px, py)));
        for (final e in nearest.take(GameConfig.bombKills)) {
          _killEnemy(e);
        }
      case DropEffect.reinforcements:
        _spawnEnemy();
    }
  }

  // --- helpers ------------------------------------------------------------

  /// A random open cell away from the rim and from the player, or null.
  int? _randomEmptyCell({required double minDistanceFromPlayer}) {
    for (var attempt = 0; attempt < 200; attempt++) {
      final c = 2 + random.nextInt(max(1, grid.columns - 4));
      final r = 2 + random.nextInt(max(1, grid.rows - 4));
      if (!grid.inBounds(c, r) || grid.stateAt(c, r) != CellState.empty) {
        continue;
      }
      final dx = c - walker.column;
      final dy = r - walker.row;
      if (sqrt(dx * dx + dy * dy) < minDistanceFromPlayer) continue;
      return grid.index(c, r);
    }
    return null;
  }
}

