import 'grid/enemy_body.dart';
import 'grid/powerups.dart';

/// Everything that makes one level what it is. Plain data: the session reads
/// it, nothing here knows how to play.
class LevelDef {
  const LevelDef({
    required this.sign,
    required this.element,
    required this.captureTarget,
    required this.enemies,
    required this.patrols,
    required this.enemySpeed,
    required this.patrolSpeed,
    required this.respawnSeconds,
    required this.pickupSeconds,
    this.layers = 1,
  });

  /// Zodiac sign, shown in the HUD.
  final String sign;

  /// The sign's element. Pickups of this element turn up three times as often.
  final ElementType element;

  /// Share of the field to capture to clear the level, 0.0 to 1.0.
  final double captureTarget;

  /// How many of each enemy kind live on the field (and are respawned).
  final Map<EnemyKind, int> enemies;

  /// How many sparks patrol the border.
  final int patrols;

  /// Multipliers on the base speeds in GameConfig. 1.0 is normal.
  final double enemySpeed;
  final double patrolSpeed;

  /// Seconds before a killed enemy is replaced.
  final double respawnSeconds;

  /// Seconds between element pickups appearing.
  final double pickupSeconds;

  /// How many fields stacked under one another this level has. Clear one and
  /// the next appears beneath it; clear the last and the level is done.
  final int layers;

  int get enemyCount => enemies.values.fold(0, (a, b) => a + b);

  /// The enemies as one list, kinds interleaved (not all bouncers first), so
  /// that spawning and respawning in order always yields a mix.
  List<EnemyKind> get roster {
    final left = Map<EnemyKind, int>.of(enemies);
    final out = <EnemyKind>[];
    while (left.values.any((n) => n > 0)) {
      for (final kind in EnemyKind.values) {
        final n = left[kind] ?? 0;
        if (n > 0) {
          out.add(kind);
          left[kind] = n - 1;
        }
      }
    }
    return out;
  }

  /// This level with some things changed. Anything not named is inherited,
  /// which is how a child level stays a few lines long.
  LevelDef copyWith({
    String? sign,
    ElementType? element,
    double? captureTarget,
    Map<EnemyKind, int>? enemies,
    int? patrols,
    double? enemySpeed,
    double? patrolSpeed,
    double? respawnSeconds,
    double? pickupSeconds,
    int? layers,
  }) =>
      LevelDef(
        sign: sign ?? this.sign,
        element: element ?? this.element,
        captureTarget: captureTarget ?? this.captureTarget,
        enemies: enemies ?? this.enemies,
        patrols: patrols ?? this.patrols,
        enemySpeed: enemySpeed ?? this.enemySpeed,
        patrolSpeed: patrolSpeed ?? this.patrolSpeed,
        respawnSeconds: respawnSeconds ?? this.respawnSeconds,
        pickupSeconds: pickupSeconds ?? this.pickupSeconds,
        layers: layers ?? this.layers,
      );
}

/// The parent level and its children, in play order.
///
/// Change a number on [parent] and every level that doesn't set it itself
/// follows. Each child below states only how it differs.
class LevelSet {
  const LevelSet({required this.parent, required this.children});

  final LevelDef parent;
  final List<LevelDef> children;

  int get length => children.length;

  /// The [level]th level (1-based). There are only [length] of them: the
  /// game deepens through each level's layers, not by going round again.
  LevelDef forLevel(int level) => children[level.clamp(1, length) - 1];

  /// Every level with the same enemy and patrol counts. For tests, which want
  /// an empty or exact field whatever the level.
  LevelSet withCounts({int? enemies, int? patrols, int? layers}) => LevelSet(
        parent: parent,
        children: [
          for (final c in children)
            c.copyWith(
              enemies: enemies == null
                  ? null
                  : {if (enemies > 0) EnemyKind.bouncer: enemies},
              patrols: patrols,
              layers: layers,
            ),
        ],
      );

  /// The tutorial's field: no enemies or patrols, a low bar, two layers so it
  /// can show a descent, and no random pickups (the script places them).
  static const LevelDef tutorialLevel = LevelDef(
    sign: 'Tutorial',
    element: ElementType.earth,
    captureTarget: 0.30,
    enemies: {},
    patrols: 0,
    enemySpeed: 1,
    patrolSpeed: 1,
    respawnSeconds: 3,
    pickupSeconds: 1e9,
    layers: 2,
  );

  /// The twelve zodiac levels.
  static final LevelSet zodiac = LevelSet(parent: _parent, children: _children);
}

/// The defaults every level starts from.
const LevelDef _parent = LevelDef(
  sign: 'Zodiac',
  element: ElementType.fire,
  captureTarget: 0.75,
  enemies: {EnemyKind.bouncer: 4, EnemyKind.drifter: 2},
  patrols: 1,
  enemySpeed: 1.0,
  patrolSpeed: 1.0,
  respawnSeconds: 3,
  pickupSeconds: 7,
  layers: 2,
);

const _bouncer = EnemyKind.bouncer;
const _hunter = EnemyKind.hunter;
const _dasher = EnemyKind.dasher;
const _drifter = EnemyKind.drifter;
const _snake = EnemyKind.snake;

/// The twelve children, easiest to hardest. Tune here.
///
/// Elements run fire, earth, air, water round the wheel, as the signs do.
final List<LevelDef> _children = [
  // 1. Gentle: no patrols, slow-witted enemies, a lower bar.
  _parent.copyWith(
    sign: 'Aries',
    element: ElementType.fire,
    captureTarget: 0.70,
    patrols: 0,
  ),
  // 2. Heavy and slow, but the first hunter appears.
  _parent.copyWith(
    sign: 'Taurus',
    element: ElementType.earth,
    captureTarget: 0.72,
    enemies: {_bouncer: 4, _drifter: 2, _hunter: 1},
    enemySpeed: 0.95,
  ),
  // 3. Twins: two dashers.
  _parent.copyWith(
    sign: 'Gemini',
    element: ElementType.air,
    enemies: {_bouncer: 3, _dasher: 2, _drifter: 2},
    enemySpeed: 1.05,
  ),
  // 4. Cancer: a drifting swarm that nonetheless hunts.
  _parent.copyWith(
    sign: 'Cancer',
    element: ElementType.water,
    enemies: {_drifter: 4, _hunter: 2, _bouncer: 2},
  ),
  // 5. Leo: bold hunters, two patrols.
  _parent.copyWith(
    sign: 'Leo',
    layers: 3,
    element: ElementType.fire,
    enemies: {_bouncer: 4, _hunter: 3, _dasher: 1},
    patrols: 2,
  ),
  // 6. Virgo: the first snake. Precise and fussy.
  _parent.copyWith(
    sign: 'Virgo',
    layers: 3,
    element: ElementType.earth,
    enemies: {_bouncer: 3, _hunter: 2, _drifter: 3, _snake: 1},
    patrols: 2,
  ),
  // 7. Libra: balance. One of everything in proportion, pickups come faster.
  _parent.copyWith(
    sign: 'Libra',
    layers: 3,
    element: ElementType.air,
    enemies: {_bouncer: 3, _hunter: 2, _dasher: 2, _drifter: 2, _snake: 1},
    patrols: 2,
    pickupSeconds: 6,
  ),
  // 8. Scorpio: hunters and snakes, tighter respawns.
  _parent.copyWith(
    sign: 'Scorpio',
    layers: 3,
    element: ElementType.water,
    enemies: {_hunter: 4, _dasher: 2, _snake: 2, _bouncer: 2},
    patrols: 2,
    enemySpeed: 1.08,
    respawnSeconds: 2.6,
  ),
  // 9. Sagittarius: arrows. Dashers everywhere.
  _parent.copyWith(
    sign: 'Sagittarius',
    layers: 4,
    element: ElementType.fire,
    enemies: {_dasher: 4, _bouncer: 3, _hunter: 2, _snake: 1},
    patrols: 2,
    enemySpeed: 1.12,
    patrolSpeed: 1.1,
  ),
  // 10. Capricorn: a long climb. Many snakes and a higher bar.
  _parent.copyWith(
    sign: 'Capricorn',
    layers: 4,
    element: ElementType.earth,
    captureTarget: 0.78,
    enemies: {_hunter: 3, _snake: 3, _bouncer: 3, _drifter: 2},
    patrols: 3,
    enemySpeed: 1.1,
    patrolSpeed: 1.1,
  ),
  // 11. Aquarius: fast and crowded.
  _parent.copyWith(
    sign: 'Aquarius',
    layers: 4,
    element: ElementType.air,
    captureTarget: 0.78,
    enemies: {_dasher: 3, _hunter: 3, _snake: 3, _drifter: 3},
    patrols: 3,
    enemySpeed: 1.18,
    patrolSpeed: 1.15,
    respawnSeconds: 2.4,
  ),
  // 12. Pisces: everything, the highest bar.
  _parent.copyWith(
    sign: 'Pisces',
    layers: 4,
    element: ElementType.water,
    captureTarget: 0.80,
    enemies: {_bouncer: 3, _hunter: 3, _dasher: 3, _drifter: 2, _snake: 4},
    patrols: 3,
    enemySpeed: 1.2,
    patrolSpeed: 1.2,
    respawnSeconds: 2.2,
  ),
];

