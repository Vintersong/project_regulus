import 'grid/claim_grid.dart';
import 'grid/drops.dart';
import 'grid/events.dart';
import 'grid/powerups.dart';
import 'grid/session.dart';

/// One instruction, and how to tell it has been done.
class TutorialStep {
  const TutorialStep(this.text, {required this.done, this.onEnter, this.keepUp});

  /// What to tell the player.
  final String text;

  /// True once the player has done it. Sees this frame's events.
  final bool Function(List<GameEvent> events) done;

  /// Sets the step up (places a pickup, a drop...).
  final void Function()? onEnter;

  /// Runs every frame while the step is current, to keep it doable (puts a
  /// pickup back if a capture swallowed it, and so on).
  final void Function()? keepUp;
}

/// The guided tutorial: a fixed script over the tutorial field. Each step
/// shows one instruction and waits until the player does it. Pure Dart over
/// [GameSession], so it can be tested without Flame.
///
/// Call [update] every frame after the session updates and BEFORE anything
/// drains the session's events, so the steps can see what just happened.
class Tutorial {
  Tutorial(this.session);

  final GameSession session;
  int index = 0;

  /// Where the player was when the "move" step began.
  int _startColumn = 0;
  int _startRow = 0;

  bool get active => session.tutorial;
  bool get finished => index >= steps.length;
  String get text => finished ? '' : steps[index].text;

  /// Starts (or restarts) the tutorial from the first step.
  void start() {
    session
      ..startTutorial()
      ..dropGoodChance = 1;
    index = 0;
    _enter();
  }

  void update() {
    if (!active || finished) return;
    // Clearing the layer is the last thing taught on layer 1: until then a
    // big early capture must not end it.
    session.holdWin = index < _clearStep;
    final step = steps[index];
    step.keepUp?.call();
    if (step.done(session.events)) {
      index++;
      if (!finished) _enter();
    }
  }

  void _enter() => steps[index].onEnter?.call();

  int get _target => (session.grid.captureTarget * 100).round();

  /// Index of the "clear the layer" step; see [update].
  static const int _clearStep = 7;

  late final List<TutorialStep> steps = [
    TutorialStep(
      'Move along the glowing border with the ARROW KEYS or WASD.\n'
      'Turning onto a line is forgiving: just hold the way you want to go.',
      onEnter: () {
        _startColumn = session.walker.column;
        _startRow = session.walker.row;
      },
      done: (_) {
        final w = session.walker;
        return (w.column - _startColumn).abs() + (w.row - _startRow).abs() >=
            20;
      },
    ),
    TutorialStep(
      'Hold SHIFT (or Z) and step into the open field to start a cut.',
      done: (e) => e.any((x) => x is CutStarted),
    ),
    TutorialStep(
      'Changed your mind? Step straight back along a short cut to undo it.\n'
      '(Start a new cut first if this one has got too long.)',
      done: (e) => e.any((x) => x is CutCancelled),
    ),
    TutorialStep(
      'Now cut across and reach the border again.\n'
      'The smaller side is claimed, and the bar at the top left fills up.\n'
      'While cutting, your line is exposed.',
      done: (e) => e.any((x) => x is Captured),
    ),
    TutorialStep(
      'An element appeared: the orb with the mountain icon (earth).\n'
      'Fire is a flame, water a droplet, air a gust. Cut out to grab it.',
      onEnter: _placePickup,
      keepUp: () {
        if (session.pickup == null && session.held == null) _placePickup();
      },
      done: (_) => session.held != null,
    ),
    TutorialStep(
      'It sits in your item slot (top centre), shown by its icon.\n'
      'Press SPACE to use it. Earth cracks the ground open and claims the pockets.\n'
      'Fire, water and air run for a few seconds: watch their icon at the top right.',
      done: (e) => e.any((x) => x is ItemUsed),
    ),
    TutorialStep(
      'A gift box is a mystery drop. Claim the ground around it, or touch it\n'
      'while cutting. In real levels it is a gamble: it can help or hurt!\n'
      'What it does shows as an icon at the top right (green good, red bad).',
      onEnter: _placeDrop,
      keepUp: () {
        if (session.drops.isEmpty) _placeDrop();
      },
      done: (e) => e.any((x) => x is DropCollected),
    ),
    TutorialStep(
      'Fill the bar up to the amber notch ($_target%) to clear this layer.',
      done: (_) => session.status == SessionStatus.won,
    ),
    TutorialStep(
      'Layer 2. Each level is a stack of layers: deeper ones change colour\n'
      'and bring more enemies. Fill the bar to the notch once more to finish.',
      // Layer 1's win is still on screen when this step begins: wait for
      // the one on layer 2.
      done: (_) => session.status == SessionStatus.won && session.layer == 2,
    ),
  ];

  void _placePickup() {
    final cell = _openCellNear(14);
    if (cell == null) return;
    // It never expires: the tutorial waits as long as it takes.
    session.pickup = Pickup(cell, ElementType.earth, double.infinity);
  }

  void _placeDrop() {
    final cell = _openCellNear(18);
    if (cell != null) session.drops.add(Drop(cell));
  }

  /// An open cell about [distance] cells (walking distance) from the player,
  /// clear of the rim, or null if the field is full.
  int? _openCellNear(int distance) {
    final g = session.grid;
    final w = session.walker;
    int? best;
    var bestError = 1 << 30;
    for (var r = 3; r < g.rows - 3; r++) {
      for (var c = 3; c < g.columns - 3; c++) {
        if (g.stateAt(c, r) != CellState.empty) continue;
        final d = (c - w.column).abs() + (r - w.row).abs();
        final error = (d - distance).abs();
        if (error < bestError) {
          best = g.index(c, r);
          bestError = error;
        }
      }
    }
    return best;
  }
}
