import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'dart:math' show max;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import 'components/actors_layer.dart';
import 'components/claim_grid_component.dart';
import 'components/move_hints.dart';
import 'components/player.dart';
import 'components/playfield_frame.dart';
import 'components/vfx_layer.dart';
import 'config.dart';
import 'grid/direction.dart';
import 'grid/powerups.dart';
import 'grid/session.dart';
import 'palette.dart';
import 'score_store.dart';
import 'tutorial.dart';

class RegulusGame extends FlameGame with KeyboardEvents {
  RegulusGame()
      : super(
          camera: CameraComponent.withFixedResolution(
            width: GameConfig.viewWidth,
            height: GameConfig.viewHeight,
          ),
        );

  /// WASD and arrow keys both map onto the four directions.
  static final Map<LogicalKeyboardKey, Direction> _keyMap = {
    LogicalKeyboardKey.arrowUp: Direction.up,
    LogicalKeyboardKey.keyW: Direction.up,
    LogicalKeyboardKey.arrowDown: Direction.down,
    LogicalKeyboardKey.keyS: Direction.down,
    LogicalKeyboardKey.arrowLeft: Direction.left,
    LogicalKeyboardKey.keyA: Direction.left,
    LogicalKeyboardKey.arrowRight: Direction.right,
    LogicalKeyboardKey.keyD: Direction.right,
  };

  /// Hold one of these with a direction to leave the border and start a cut.
  static final Set<LogicalKeyboardKey> _cutKeys = {
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.keyZ,
  };

  static final Map<LogicalKeyboardKey, ElementType> _debugGrants = {
    LogicalKeyboardKey.digit1: ElementType.fire,
    LogicalKeyboardKey.digit2: ElementType.water,
    LogicalKeyboardKey.digit3: ElementType.air,
    LogicalKeyboardKey.digit4: ElementType.earth,
  };

  /// All the rules live here; the components below only draw it.
  final GameSession session = GameSession(spawnDrops: true);

  /// The guided tutorial's script; runs by itself on the first launch.
  late final Tutorial tutorial = Tutorial(session);
  final ProgressStore _progress = ProgressStore();

  /// Held directions in press order; the most recent one wins.
  final List<Direction> _held = [];
  Direction? get heldDirection => _held.isEmpty ? null : _held.last;

  late final TextComponent _status; // top-left: progress and lives
  late final TextComponent _effects; // top-right: running elements
  late final TextComponent _banner; // centre: win / game over
  late final TextComponent _score; // bottom-left: score, combo, best
  late final TextComponent _level; // bottom-right
  late final TextComponent _lesson; // tutorial instruction, top of the field

  final ScoreStore _store = ScoreStore();
  int best = 0;
  bool _newBest = false;
  SessionStatus _lastStatus = SessionStatus.playing;

  @override
  Color backgroundColor() => Palette.background;

  @override
  Future<void> onLoad() async {
    // World coordinates match the logical view: (0,0) is top-left.
    camera.viewfinder.anchor = Anchor.topLeft;

    TextComponent label(Vector2 position, Anchor anchor, double size) =>
        TextComponent(
          position: position,
          anchor: anchor,
          priority: 20,
          textRenderer: TextPaint(
            style: TextStyle(color: Palette.line, fontSize: size),
          ),
        );

    _status = label(Vector2(GameConfig.playfieldLeft, 10), Anchor.topLeft, 20);
    _effects = label(
      Vector2(GameConfig.playfieldLeft + GameConfig.playfieldWidth, 10),
      Anchor.topRight,
      20,
    );
    _banner = label(
      Vector2(GameConfig.viewWidth / 2, GameConfig.viewHeight / 2),
      Anchor.center,
      44,
    );

    _lesson = TextComponent(
      position: Vector2(GameConfig.viewWidth / 2, GameConfig.playfieldTop + 18),
      anchor: Anchor.topCenter,
      priority: 25,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFF2FFFB),
          fontSize: 22,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Color(0xFF000000), blurRadius: 6)],
        ),
      ),
    );

    // Bottom margin: score and combo on the left, level on the right.
    final bottom = GameConfig.playfieldTop + GameConfig.playfieldHeight + 8;
    _score = label(Vector2(GameConfig.playfieldLeft, bottom), Anchor.topLeft, 20);
    _level = label(
      Vector2(GameConfig.playfieldLeft + GameConfig.playfieldWidth, bottom),
      Anchor.topRight,
      20,
    );

    // A reminder of the two actions that aren't just moving.
    world.add(
      TextComponent(
        text: 'SHIFT / Z: cut     SPACE: use item',
        position: Vector2(GameConfig.viewWidth / 2, bottom + 3),
        anchor: Anchor.topCenter,
        priority: 20,
        textRenderer: TextPaint(
          style: TextStyle(
            color: Palette.line.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
      ),
    );

    best = await _store.load();
    // First launch: the tutorial runs by itself (ESC skips it).
    if (!await _progress.tutorialDone()) tutorial.start();

    // Dev: REGULUS_DEMO=1 starts with some ground already won, so the shine
    // and the walkable-edge feedback can be looked at straight away. One
    // block touches the border (reachable), one floats free (not reachable).
    if (kDebugMode && Platform.environment['REGULUS_DEMO'] == '1') {
      session.debugClaimRect(1, 1, 100, 70);
      session.debugClaimRect(120, 30, 200, 110);
    }

    world.addAll([
      LayerBackdrop(session),
      ClaimGridComponent(session),
      PlayfieldFrame(),
      ActorsLayer(session),
      MoveHints(session),
      Player(
        session.walker,
        session.effects,
        isArmed: () => session.canStartCut,
      ),
      VfxLayer(
        session,
        // The camera trembling is the screen shake.
        onShake: (o) => camera.viewfinder.position = Vector2(o.dx, o.dy),
      ),
      _status,
      _effects,
      _banner,
      _score,
      _level,
      _lesson,
      // Debug builds only: frames per second, to spot a slowdown over time.
      if (kDebugMode)
        FpsTextComponent(
          position: Vector2(GameConfig.viewWidth / 2, 6),
          anchor: Anchor.topCenter,
          priority: 30,
          textRenderer: TextPaint(
            style: TextStyle(
              color: Palette.line.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ),
    ]);
  }

  @override
  void update(double dt) {
    session.update(dt, heldDirection);
    // Before the effects layer drains this frame's events: the tutorial
    // watches them to tell when a step is done.
    tutorial.update();
    super.update(dt);
    if (!isLoaded) return;
    _trackStatus();
    _refreshHud();
  }

  /// Saves a new best when a run or a level ends.
  void _trackStatus() {
    if (session.status == _lastStatus) return;
    _lastStatus = session.status;
    if (session.status == SessionStatus.playing) {
      _newBest = false;
      return;
    }
    if (session.tutorial) return; // practice doesn't count for the best
    if (session.score > best) {
      best = session.score;
      _newBest = true;
      unawaited(_store.save(best));
    }
  }

  /// Remembers the tutorial is done, so it won't run by itself again.
  void _finishTutorial() => unawaited(_progress.markTutorialDone());

  static String _commas(int n) => n.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
      );

  void _refreshHud() {
    final percent = (session.grid.claimedFraction * 100).floor();
    final target = (session.grid.captureTarget * 100).round();
    _status.text = 'Claimed $percent% / $target%    Lives ${session.lives}';

    _effects.text = [
      for (final e in session.effects.running)
        '${e.key.name.toUpperCase()} ${e.value.toStringAsFixed(1)}s',
      for (final e in session.dropEffects.running)
        '${e.key.label} ${e.value.toStringAsFixed(1)}s',
      if (session.shield) 'SHIELD',
    ].join('   ');

    final combo = session.combo > 1
        ? '     COMBO x${session.combo} (${session.comboTimeLeft.toStringAsFixed(1)}s)'
        : '';
    _score.text = 'Score ${_commas(session.score)}$combo'
        '     Best ${_commas(max(best, session.score))}';
    _level.text = session.tutorial
        ? 'Tutorial    Layer ${session.layer}/${session.layerCount}'
        : 'Level ${session.level}/${session.levelCount}  '
            '${session.def.sign}    Layer ${session.layer}/${session.layerCount}';

    _lesson.text = session.tutorial && session.status == SessionStatus.playing
        ? 'TUTORIAL ${tutorial.index + 1}/${tutorial.steps.length}\n'
            '${tutorial.text}\n\nESC: skip tutorial'
        : '';

    final scoreLine =
        'Score ${_commas(session.score)}${_newBest ? '  NEW BEST!' : ''}';
    _banner.text = switch (session.status) {
      SessionStatus.playing => '',
      SessionStatus.won when session.tutorial && session.isLastLayer =>
        'Tutorial complete!\n'
            'Out in the real levels, enemies hit\n'
            'your open line while you cut. Good luck.\n'
            'Space: start Aries',
      SessionStatus.won when !session.isLastLayer =>
        '${session.def.sign}: layer ${session.layer} cleared\n'
            '+${_commas(session.levelBonus)} bonus\n'
            '$scoreLine\n'
            'Space: descend to layer ${session.layer + 1}',
      SessionStatus.won => '${session.def.sign} cleared\n'
          '+${_commas(session.levelBonus)} bonus\n'
          '$scoreLine\n'
          'Space: next level',
      SessionStatus.complete => 'The zodiac is yours\n'
          '+${_commas(session.levelBonus)} bonus\n'
          '$scoreLine\n'
          'Space: play again    T: tutorial',
      SessionStatus.lost => 'Game over\n'
          '$scoreLine\n'
          'Space: try again    T: tutorial',
    };
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    // A cut only starts while the cut key is held.
    session.canStartCut = keysPressed.any(_cutKeys.contains);
    if (_cutKeys.contains(event.logicalKey)) return KeyEventResult.handled;

    if (event is KeyDownEvent) {
      // ESC skips the tutorial; T replays it from an end-of-run screen.
      if (event.logicalKey == LogicalKeyboardKey.escape && session.tutorial) {
        _finishTutorial();
        session.restart();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyT &&
          (session.status == SessionStatus.lost ||
              session.status == SessionStatus.complete)) {
        tutorial.start();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        // Space fires the held item mid-run. After a win it goes down a layer
        // or on to the next level; after a loss or the final win, a new run.
        switch (session.status) {
          case SessionStatus.playing:
            session.useHeld();
          case SessionStatus.won:
            if (session.tutorial && session.isLastLayer) _finishTutorial();
            session.nextLevel();
          case SessionStatus.lost:
          case SessionStatus.complete:
            session.restart();
        }
        return KeyEventResult.handled;
      }
      // Dev shortcuts: 1-4 put fire, water, air, earth in the item slot
      // (debug builds only). Space then fires it, as in a real run.
      if (kDebugMode && session.status == SessionStatus.playing) {
        final item = _debugGrants[event.logicalKey];
        if (item != null) {
          session.held = item;
          return KeyEventResult.handled;
        }
      }
      final direction = _keyMap[event.logicalKey];
      if (direction != null) {
        _held
          ..remove(direction)
          ..add(direction);
      }
    }
    // Drop any direction whose keys are all released.
    _held.removeWhere(
      (d) => !_keyMap.entries.any(
        (e) => e.value == d && keysPressed.contains(e.key),
      ),
    );
    return _keyMap.containsKey(event.logicalKey)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }
}
