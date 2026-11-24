def edit(p, pairs):
    s=open(p,encoding="utf-8").read()
    for o,n in pairs:
        assert o in s,(p,o[:50]); s=s.replace(o,n,1)
    open(p,"w",encoding="utf-8").write(s)

G="lib/game/regulus_game.dart"
edit(G,[
("import 'score_store.dart';","import 'score_store.dart';\nimport 'tutorial.dart';"),
("""  /// Held directions in press order; the most recent one wins.""","""  /// The guided tutorial's script; runs on the first launch.
  late final Tutorial tutorial = Tutorial(session);
  final ProgressStore _progress = ProgressStore();

  /// Held directions in press order; the most recent one wins."""),
("  late final TextComponent _level; // bottom-right\n","  late final TextComponent _level; // bottom-right\n  late final TextComponent _lesson; // tutorial instruction, top of field\n"),
("""    // Bottom margin: score and combo on the left, level on the right.""","""    _lesson = TextComponent(
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

    // Bottom margin: score and combo on the left, level on the right."""),
("""    best = await _store.load();
""","""    best = await _store.load();
    // First launch: the tutorial runs by itself (ESC skips it).
    if (!await _progress.tutorialDone()) tutorial.start();
"""),
("      _level,\n      // Debug builds only","      _level,\n      _lesson,\n      // Debug builds only"),
("""    session.update(dt, heldDirection);
    super.update(dt);""","""    session.update(dt, heldDirection);
    // Before the effects layer drains this frame's events: the tutorial
    // watches them to see when a step is done.
    tutorial.update();
    super.update(dt);"""),
("""    if (session.status == SessionStatus.playing) {
      _newBest = false;
      return;
    }
    if (session.score > best) {""","""    if (session.status == SessionStatus.playing) {
      _newBest = false;
      return;
    }
    if (session.tutorial) return; // practice doesn't count for the best
    if (session.score > best) {"""),
("""    _level.text = 'Level ${session.level}/${session.levelCount}  '
        '${session.def.sign}    Layer ${session.layer}/${session.layerCount}';
""","""    _level.text = session.tutorial
        ? 'Tutorial    Layer ${session.layer}/${session.layerCount}'
        : 'Level ${session.level}/${session.levelCount}  '
            '${session.def.sign}    Layer ${session.layer}/${session.layerCount}';

    _lesson.text =
        session.tutorial && session.status == SessionStatus.playing
            ? 'TUTORIAL ${tutorial.index + 1}/${tutorial.steps.length}\n'
                '${tutorial.text}\n\nESC: skip tutorial'
            : '';
"""),
("""      SessionStatus.playing => '',
      SessionStatus.won when !session.isLastLayer =>""","""      SessionStatus.playing => '',
      SessionStatus.won when session.tutorial && session.isLastLayer =>
        'Tutorial complete!\n'
            'You know the ropes. Watch out for enemies:\n'
            'they hit your line while you cut.\n'
            'Space: start Aries',
      SessionStatus.won when !session.isLastLayer =>"""),
("""          'Space: play again',
      SessionStatus.lost => 'Game over\n'
          '$scoreLine\n'
          'Space: try again',""","""          'Space: play again    T: tutorial',
      SessionStatus.lost => 'Game over\n'
          '$scoreLine\n'
          'Space: try again    T: tutorial',"""),
("""    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space ||""","""    if (event is KeyDownEvent) {
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
      if (event.logicalKey == LogicalKeyboardKey.space ||"""),
("""          case SessionStatus.won:
            session.nextLevel();""","""          case SessionStatus.won:
            if (session.tutorial && session.isLastLayer) _finishTutorial();
            session.nextLevel();"""),
])
s=open(G,encoding="utf-8").read()
s=s.replace("""  static String _commas(int n)""","""  /// Remembers the tutorial is done, so it won't run by itself again.
  void _finishTutorial() => unawaited(_progress.markTutorialDone());

  static String _commas(int n)""",1)
open(G,"w",encoding="utf-8").write(s)
print("ok")
