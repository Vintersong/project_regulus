import 'dart:math';

import '../config.dart';
import 'claim_grid.dart';

enum _Probe { open, trail, wall }

/// How an enemy moves. Each kind also has its own look in the actors layer.
enum EnemyKind {
  /// Straight lines, bounces off everything. The baseline.
  bouncer(1.0),

  /// Slower, but while you are mid-cut it steers toward you.
  hunter(0.7),

  /// Creeps, then bursts fast in a random direction.
  dasher(0.5),

  /// Erratic: keeps changing heading.
  drifter(0.9),

  /// A slithering chain: the head wanders in S-curves and the body drags along
  /// behind it, so any part of it touching your line is deadly.
  snake(0.8);

  const EnemyKind(this.speedFactor);

  /// Share of [GameConfig.enemyCellsPerSecond] this kind cruises at.
  final double speedFactor;
}

/// A moving enemy. Lives in grid-cell units (x, y are fractional cells), so
/// it is independent of screen size like everything else on the grid.
class EnemyBody {
  EnemyBody({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    this.kind = EnemyKind.bouncer,
  }) : _speed = sqrt(vx * vx + vy * vy) {
    if (kind == EnemyKind.snake) _seedBody();
  }

  final EnemyKind kind;

  double x;
  double y;

  /// Velocity in cells per second.
  double vx;
  double vy;

  /// Cruising speed, fixed at birth. [think] steers the heading around it.
  final double _speed;

  // Shared timer: a dasher's phase, a drifter's time to the next turn.
  double _timer = 1.0;
  bool _dashing = false;

  /// True while a dasher is mid-burst.
  bool get dashing => _dashing;

  double _phase = 0; // a snake's slither

  /// Where the head has been, newest first. A snake's body hangs off this.
  final List<Point<double>> _path = [];

  /// Body points, nearest the head first. Empty for everything but a snake.
  List<Point<double>> get segments => [
        if (kind == EnemyKind.snake)
          for (var k = 1;
              k <= GameConfig.snakeSegments &&
                  k * GameConfig.snakeSegmentGap < _path.length;
              k++)
            _path[k * GameConfig.snakeSegmentGap],
      ];

  /// Lays the body out straight behind the head, so a new snake isn't a dot.
  void _seedBody() {
    final back = heading + pi;
    final samples = GameConfig.snakeSegments * GameConfig.snakeSegmentGap + 1;
    for (var i = 0; i < samples; i++) {
      final d = i * GameConfig.snakePathSpacing;
      _path.add(Point(x + cos(back) * d, y + sin(back) * d));
    }
  }

  void _recordPath() {
    if (kind != EnemyKind.snake) return;
    final head = Point(x, y);
    if (_path.isNotEmpty &&
        _path.first.distanceTo(head) < GameConfig.snakePathSpacing) {
      return;
    }
    _path.insert(0, head);
    final keep = GameConfig.snakeSegments * GameConfig.snakeSegmentGap + 1;
    if (_path.length > keep) _path.removeRange(keep, _path.length);
  }

  static bool _isTrail(ClaimGrid grid, double px, double py) {
    final c = px.floor();
    final r = py.floor();
    return grid.inBounds(c, r) && grid.stateAt(c, r) == CellState.trail;
  }

  /// True if any body segment (not the head) is inside the player's open line.
  bool segmentTouchesTrail(ClaimGrid grid) =>
      segments.any((p) => _isTrail(grid, p.x, p.y));

  /// True if any part of the enemy, head or body, is inside the open line.
  bool occupiesTrail(ClaimGrid grid) =>
      _isTrail(grid, x, y) || segmentTouchesTrail(grid);

  /// Distance in cells from ([px], [py]) to the nearest part of the enemy.
  double distanceTo(double px, double py) {
    var best = sqrt((x - px) * (x - px) + (y - py) * (y - py));
    for (final p in segments) {
      best = min(best, sqrt((p.x - px) * (p.x - px) + (p.y - py) * (p.y - py)));
    }
    return best;
  }

  /// Direction of travel in radians.
  double get heading => atan2(vy, vx);

  int get column => x.floor();
  int get row => y.floor();

  /// Decides this frame's heading and speed for the enemy's kind. Call it
  /// before [update]. [targetX] and [targetY] are where a hunter should aim,
  /// or null when there is nothing to hunt.
  void think(
    double dt,
    Random random, {
    double? targetX,
    double? targetY,
  }) {
    switch (kind) {
      case EnemyKind.bouncer:
        return;

      case EnemyKind.hunter:
        if (targetX == null || targetY == null) return; // nothing to hunt
        var diff = atan2(targetY - y, targetX - x) - heading;
        while (diff > pi) {
          diff -= 2 * pi;
        }
        while (diff < -pi) {
          diff += 2 * pi;
        }
        // A limited turn rate lets you dodge by changing direction.
        final maxTurn = GameConfig.hunterTurnRate * dt;
        _aim(heading + diff.clamp(-maxTurn, maxTurn).toDouble(), _speed);

      case EnemyKind.dasher:
        _timer -= dt;
        var angle = heading;
        if (_timer <= 0) {
          _dashing = !_dashing;
          if (_dashing) {
            _timer = GameConfig.dashSeconds;
            angle = random.nextDouble() * 2 * pi;
          } else {
            _timer = 1.2 + random.nextDouble() * 1.2;
          }
        }
        _aim(angle, _dashing ? _speed * GameConfig.dashSpeedScale : _speed);

      case EnemyKind.drifter:
        _timer -= dt;
        var angle = heading;
        if (_timer <= 0) {
          _timer = 0.4 + random.nextDouble() * 0.8;
          angle += (random.nextDouble() - 0.5) * pi * 1.2;
        }
        _aim(angle, _speed);

      case EnemyKind.snake:
        // Heading swings left and right in a steady rhythm: a slither.
        _phase += dt * 2.2;
        _aim(heading + sin(_phase) * GameConfig.snakeWobble * dt, _speed);
    }
  }

  void _aim(double angle, double speed) {
    vx = cos(angle) * speed;
    vy = sin(angle) * speed;
  }

  /// No substep moves further than this many cells, so even a fast dasher
  /// can't hop over a one-cell-wide trail.
  static const double _maxStepCells = 0.5;

  /// Moves one frame and bounces off anything that is not open ground.
  ///
  /// Returns true if it moved into a cell of the player's open trail. The
  /// enemy passes through; the caller decides what that means (a death, a
  /// fire kill, or nothing under water).
  bool update(double dt, ClaimGrid grid, {double speedScale = 1}) {
    final travel = max(vx.abs(), vy.abs()) * dt * speedScale;
    final steps = max(1, (travel / _maxStepCells).ceil());
    var touchedTrail = false;
    for (var i = 0; i < steps; i++) {
      if (_stepOnce(dt / steps, grid, speedScale)) touchedTrail = true;
    }
    _recordPath();
    return touchedTrail;
  }

  bool _stepOnce(double dt, ClaimGrid grid, double speedScale) {
    var touchedTrail = false;

    final nx = x + vx * dt * speedScale;
    switch (_probe(grid, nx.floor(), row)) {
      case _Probe.open:
        x = nx;
      case _Probe.trail:
        x = nx;
        touchedTrail = true;
      case _Probe.wall:
        vx = -vx;
    }

    final ny = y + vy * dt * speedScale;
    switch (_probe(grid, column, ny.floor())) {
      case _Probe.open:
        y = ny;
      case _Probe.trail:
        y = ny;
        touchedTrail = true;
      case _Probe.wall:
        vy = -vy;
    }

    return touchedTrail;
  }

  static _Probe _probe(ClaimGrid grid, int column, int row) {
    if (!grid.inBounds(column, row)) return _Probe.wall;
    return switch (grid.stateAt(column, row)) {
      CellState.empty => _Probe.open,
      CellState.trail => _Probe.trail,
      _ => _Probe.wall,
    };
  }
}
