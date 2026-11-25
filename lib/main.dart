import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'game/grid/session.dart' show SessionStatus;
import 'game/input_mode.dart';
import 'game/palette.dart';
import 'game/regulus_game.dart';
import 'ui/touch_controls.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RegulusApp());
}

class RegulusApp extends StatelessWidget {
  const RegulusApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The game draws everything itself, so the bare widgets layer is enough.
    return WidgetsApp(
      title: 'Regulus',
      color: Palette.letterbox,
      debugShowCheckedModeBanner: false,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, _) => builder(context),
          ),
      home: const RegulusShell(),
    );
  }
}

/// The game plus, on a touch screen, a D-pad on the left and the action
/// buttons on the right. The controls sit in their own columns beside the
/// game rather than over it, so they never hide the border you walk along.
class RegulusShell extends StatefulWidget {
  const RegulusShell({super.key});

  @override
  State<RegulusShell> createState() => _RegulusShellState();
}

class _RegulusShellState extends State<RegulusShell> {
  // One game for the life of the shell, however the layout changes around it.
  final RegulusGame _game = RegulusGame();
  final GlobalKey _gameKey = GlobalKey();
  bool _pausedForRotate = false;

  /// Pauses the game while the "rotate your device" prompt covers it. Done
  /// after the frame: pausing tells the GameWidget to rebuild.
  void _syncPause(bool shouldPause) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (shouldPause && !_pausedForRotate) {
        _pausedForRotate = true;
        _game.pauseEngine();
      } else if (!shouldPause && _pausedForRotate) {
        _pausedForRotate = false;
        _game.resumeEngine();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      // The first finger on the screen switches the touch controls on.
      onPointerDown: (e) {
        if (e.kind == PointerDeviceKind.touch ||
            e.kind == PointerDeviceKind.stylus) {
          InputMode.touch.value = true;
        }
      },
      child: ColoredBox(
        color: Palette.letterbox,
        // Keeps clear of notches and rounded corners (the web page asks for
        // the full screen with viewport-fit=cover).
        child: SafeArea(
          child: ValueListenableBuilder<bool>(
            valueListenable: InputMode.touch,
            builder: (context, touch, _) => LayoutBuilder(
              builder: (context, box) {
                final portrait = box.maxHeight > box.maxWidth;
                final showRotate = touch && portrait;
                _syncPause(showRotate);

                // Each side column: about 40% of the height, never more than
                // a quarter of the width. Zero without touch, so nothing about
                // the keyboard layout changes.
                final side = touch && !portrait
                    ? math.min(
                        math.max(box.maxHeight * 0.42, 110.0),
                        box.maxWidth * 0.25,
                      )
                    : 0.0;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Row(
                        children: [
                          SizedBox(
                            width: side,
                            child: side == 0
                                ? null
                                : Align(
                                    alignment: const Alignment(0, 0.6),
                                    child: DPad(game: _game, size: side - 16),
                                  ),
                          ),
                          Expanded(
                            child: Stack(
                              children: [
                                // .controlled-style ownership: the shell
                                // holds the game, the widget just shows it.
                                GameWidget<RegulusGame>(
                                  key: _gameKey,
                                  game: _game,
                                ),
                                // On a result screen, a tap anywhere goes on.
                                Positioned.fill(
                                  child: ValueListenableBuilder<SessionStatus>(
                                    valueListenable: _game.statusListenable,
                                    builder: (context, status, _) =>
                                        !touch || status == SessionStatus.playing
                                            ? const SizedBox.shrink()
                                            : Listener(
                                                behavior: HitTestBehavior.opaque,
                                                onPointerDown: (_) =>
                                                    _game.tapToContinue(),
                                              ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: side,
                            child: side == 0
                                ? null
                                : ActionButtons(game: _game, width: side),
                          ),
                        ],
                      ),
                    ),
                    if (showRotate)
                      const Positioned.fill(child: RotatePrompt()),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
