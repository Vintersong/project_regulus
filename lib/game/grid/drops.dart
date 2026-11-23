import 'dart:math';

/// What a mystery drop can do. Applied the instant it is collected; nothing
/// goes in the held slot. Good and bad are rolled separately (see [rollDrop]),
/// so the odds of a gamble going wrong do not depend on how many of each
/// there are.
enum DropEffect {
  // --- good ---
  /// Enemies and patrols freeze, harmless, for a few seconds.
  timeStop('TIME STOP', good: true, seconds: 4),

  /// Enemies run at half speed.
  slow('SLOWED', good: true, seconds: 6),

  /// The next hit is absorbed.
  shield('SHIELD', good: true),

  /// One more life, up to the cap.
  extraLife('+1 LIFE', good: true),

  /// A flat score bonus.
  jackpot('JACKPOT', good: true),

  /// The nearest enemies are destroyed.
  bomb('BOMB', good: true),

  // --- bad ---
  /// Everything hostile runs faster.
  rush('RUSH', good: false, seconds: 6),

  /// You move slowly.
  sluggish('SLUGGISH', good: false, seconds: 5),

  /// Another enemy joins the field.
  reinforcements('REINFORCEMENTS', good: false);

  const DropEffect(this.label, {required this.good, this.seconds = 0});

  final String label;
  final bool good;

  /// How long a timed effect lasts; 0 for instant ones.
  final double seconds;
}

/// Picks a random effect. [goodChance] is the odds of a good one (0.5 is a
/// straight gamble); within a side every effect is equally likely.
DropEffect rollDrop(Random random, {double goodChance = 0.5}) {
  final wantGood = random.nextDouble() < goodChance;
  final pool = [for (final e in DropEffect.values) if (e.good == wantGood) e];
  return pool[random.nextInt(pool.length)];
}

/// A mystery drop buried in the field. It does not say what it will do.
class Drop {
  Drop(this.cell);

  /// Flat grid index.
  final int cell;
}

/// Timed drop effects running on the player.
class DropTimers {
  final Map<DropEffect, double> _left = {};

  void activate(DropEffect e) {
    if (e.seconds > 0) _left[e] = e.seconds;
  }

  bool isActive(DropEffect e) => (_left[e] ?? 0) > 0;
  double remaining(DropEffect e) => _left[e] ?? 0;
  Iterable<MapEntry<DropEffect, double>> get running => _left.entries;

  void tick(double dt) {
    _left.updateAll((_, s) => s - dt);
    _left.removeWhere((_, s) => s <= 0);
  }

  void clear() => _left.clear();
}
