/// The four elements. Each is a pickup with a distinct effect.
enum ElementType {
  /// The player's line burns: enemies that touch it die instead of killing you.
  fire(6),

  /// Enemies pass through the line. Strongest effect, so it is short.
  water(3),

  /// You are faster, but enemies speed up too.
  air(5),

  /// Instant earthquake: cracks split the ground around you. They become new
  /// border, and any pocket they wall off is captured by the usual rule.
  earth(0);

  const ElementType(this.duration);

  /// Seconds the effect lasts; 0 means it fires once on pickup.
  final double duration;
}

/// An element sitting in open territory, waiting to be cut to.
class Pickup {
  Pickup(this.cell, this.element, this.timeLeft);

  /// Flat grid index.
  final int cell;
  final ElementType element;
  double timeLeft;
}

/// One fissure from an earthquake. Kept briefly so it can be drawn growing
/// and fading; the ground itself changed the instant it opened.
class Crack {
  Crack(this.cells);

  /// Flat grid indices, in order from the player outward.
  final List<int> cells;

  /// Seconds since it opened.
  double age = 0;
}

/// Timed effects currently running on the player.
class ActiveEffects {
  final Map<ElementType, double> _left = {};

  /// Starts (or refreshes) a timed effect. Instant elements do nothing here.
  void activate(ElementType type) {
    if (type.duration > 0) _left[type] = type.duration;
  }

  bool isActive(ElementType type) => (_left[type] ?? 0) > 0;

  double remaining(ElementType type) => _left[type] ?? 0;

  Iterable<MapEntry<ElementType, double>> get running => _left.entries;

  /// The running effect with the most time left, or null. Drives the tint.
  ElementType? get dominant {
    ElementType? best;
    var bestLeft = 0.0;
    for (final e in _left.entries) {
      if (e.value > bestLeft) {
        best = e.key;
        bestLeft = e.value;
      }
    }
    return best;
  }

  void tick(double dt) {
    _left.updateAll((_, seconds) => seconds - dt);
    _left.removeWhere((_, seconds) => seconds <= 0);
  }

  void clear() => _left.clear();
}
