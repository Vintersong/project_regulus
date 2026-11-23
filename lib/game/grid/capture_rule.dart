import 'claim_grid.dart';

/// Decides whether a pocket of open territory is captured when the player
/// closes a trail.
///
/// [enemyCells] holds the flat grid index of every enemy. [allRegions] is every
/// pocket the trail just created, [region] is the one being judged.
///
/// This is THE rule that defines how the game feels. Options:
///
///  * Enemy-based (classic Volfied/Qix, and what docs/design.md plans):
///    claim a pocket only if no enemy is inside it. Fair, and lets the player
///    gamble on trapping an enemy in the smaller side. If every pocket holds
///    an enemy, nothing is claimed.
///  * Smaller-side: always claim every pocket except the largest. Simple and
///    never fails, but enemies can end up sealed inside claimed ground, so it
///    needs a rule for them (kill, push out), and it removes the risk.
///  * Hybrid: enemy-based, with a smaller-side fallback when all pockets hold
///    an enemy, so a closed trail always gains something.
///
/// Chosen: the hybrid. A pocket holding two enemies stays open.
bool shouldClaimRegion({
  required Region region,
  required List<Region> allRegions,
  required Set<int> enemyCells,
}) {
  bool hasEnemy(Region r) => r.cells.any(enemyCells.contains);

  // If no pocket holds an enemy, enemies can't tell the pockets apart (and
  // claiming all of them would take the whole field). If every pocket holds
  // one, the enemy rule would claim nothing and waste the trail. Either way,
  // fall back to claiming all but the largest.
  final withEnemy = allRegions.where(hasEnemy).length;
  if (withEnemy == 0 || withEnemy == allRegions.length) {
    final largest = allRegions.reduce((a, b) => a.size >= b.size ? a : b);
    return !identical(region, largest);
  }

  // Mixed: a pocket is captured only if no enemy is inside it.
  return !hasEnemy(region);
}
