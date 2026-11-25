import 'package:flutter/widgets.dart';

import '../game/grid/direction.dart';
import '../game/grid/session.dart' show SessionStatus;
import '../game/palette.dart';
import '../game/regulus_game.dart';

/// Which way a finger at [fromCenter] (an offset from the pad's centre) is
/// pointing, for a pad of [radius]. Null inside the dead zone.
///
/// [current] makes the call sticky: a finger drifting across the diagonal
/// keeps its axis until it is clearly on the other one, so a thumb rolling
/// around doesn't flicker between directions.
Direction? padDirection(Offset fromCenter, double radius, Direction? current) {
  if (fromCenter.distance < radius * 0.2) return null;
  final ax = fromCenter.dx.abs();
  final ay = fromCenter.dy.abs();
  final horizontal = switch (current) {
    Direction.left || Direction.right => ax >= ay * 0.75,
    Direction.up || Direction.down => ax > ay * 1.33,
    null => ax > ay,
  };
  if (horizontal) return fromCenter.dx > 0 ? Direction.right : Direction.left;
  return fromCenter.dy > 0 ? Direction.down : Direction.up;
}

const TextStyle _labelStyle = TextStyle(
  color: Palette.line,
  fontWeight: FontWeight.bold,
  decoration: TextDecoration.none,
);

/// A round pad you slide a thumb over: it holds whichever of the four
/// directions the thumb is pointing, and lets go when the thumb lifts.
class DPad extends StatefulWidget {
  const DPad({super.key, required this.game, required this.size});

  final RegulusGame game;
  final double size;

  @override
  State<DPad> createState() => _DPadState();
}

class _DPadState extends State<DPad> {
  final ValueNotifier<Direction?> _active = ValueNotifier<Direction?>(null);
  int? _pointer;

  void _set(Direction? next) {
    if (next == _active.value) return;
    _active.value = next;
    widget.game.setTouchDirection(next);
  }

  void _track(Offset local) {
    final r = widget.size / 2;
    _set(padDirection(local - Offset(r, r), r, _active.value));
  }

  void _end(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _set(null);
  }

  @override
  void dispose() {
    // The pad can vanish mid-press (rotating, a key press); don't leave the
    // player walking.
    if (_pointer != null) widget.game.setTouchDirection(null);
    _active.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_pointer != null) return;
        _pointer = e.pointer;
        _track(e.localPosition);
      },
      onPointerMove: (e) {
        if (e.pointer == _pointer) _track(e.localPosition);
      },
      onPointerUp: _end,
      onPointerCancel: _end,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _DPadPainter(_active),
      ),
    );
  }
}

class _DPadPainter extends CustomPainter {
  _DPadPainter(this.active) : super(repaint: active);

  final ValueNotifier<Direction?> active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()..color = Palette.letterbox.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..color = Palette.line.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final d in Direction.values) {
      final on = active.value == d;
      final v = Offset(d.dc.toDouble(), d.dr.toDouble());
      final p = Offset(-v.dy, v.dx); // across the arrow
      final tip = c + v * (r * 0.78);
      final base = c + v * (r * 0.42);
      final half = p * (r * 0.26);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(base.dx + half.dx, base.dy + half.dy)
          ..lineTo(base.dx - half.dx, base.dy - half.dy)
          ..close(),
        Paint()
          ..color = on ? Palette.accent : Palette.line.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(_DPadPainter old) => old.active != active;
}

/// A button that reacts the instant a finger lands (no tap delay), tracks
/// its own finger, and so works alongside the D-pad under the other thumb.
class _TouchButton extends StatefulWidget {
  const _TouchButton({
    required this.label,
    required this.width,
    required this.height,
    this.round = true,
    this.fontSize = 16,
    this.onDown,
    this.onUp,
  });

  final String label;
  final double width;
  final double height;
  final bool round;
  final double fontSize;
  final VoidCallback? onDown;
  final VoidCallback? onUp;

  @override
  State<_TouchButton> createState() => _TouchButtonState();
}

class _TouchButtonState extends State<_TouchButton> {
  int? _pointer;
  bool _down = false;

  void _press(PointerEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    setState(() => _down = true);
    widget.onDown?.call();
  }

  void _release(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    setState(() => _down = false);
    widget.onUp?.call();
  }

  @override
  void dispose() {
    // Gone mid-press: let go, or a held CUT would stay held.
    if (_pointer != null) widget.onUp?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _press,
      onPointerUp: _release,
      onPointerCancel: _release,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: widget.round ? BoxShape.circle : BoxShape.rectangle,
            borderRadius:
                widget.round ? null : BorderRadius.circular(widget.height / 2),
            color: _down
                ? Palette.accent.withValues(alpha: 0.5)
                : Palette.letterbox.withValues(alpha: 0.55),
            border: Border.all(
              color: _down ? Palette.accent : Palette.line.withValues(alpha: 0.6),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: _labelStyle.copyWith(fontSize: widget.fontSize),
            ),
          ),
        ),
      ),
    );
  }
}

/// The right-hand column: CUT (hold) and ITEM (tap), with SKIP / TUTORIAL
/// above them when those apply.
class ActionButtons extends StatelessWidget {
  const ActionButtons({super.key, required this.game, required this.width});

  final RegulusGame game;
  final double width;

  @override
  Widget build(BuildContext context) {
    final inner = width - 16;
    final cut = inner * 0.78;
    final item = inner * 0.52;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ValueListenableBuilder<SessionStatus>(
            valueListenable: game.statusListenable,
            builder: (context, status, _) => ValueListenableBuilder<bool>(
              valueListenable: game.tutorialListenable,
              builder: (context, inTutorial, _) {
                if (inTutorial && status == SessionStatus.playing) {
                  return _TouchButton(
                    label: 'SKIP',
                    width: inner * 0.7,
                    height: 34,
                    round: false,
                    fontSize: 13,
                    onDown: game.skipTutorial,
                  );
                }
                if (status == SessionStatus.lost ||
                    status == SessionStatus.complete) {
                  return _TouchButton(
                    label: 'TUTORIAL',
                    width: inner * 0.9,
                    height: 34,
                    round: false,
                    fontSize: 13,
                    onDown: game.replayTutorial,
                  );
                }
                return const SizedBox(height: 34);
              },
            ),
          ),
          const Spacer(),
          _TouchButton(
            label: 'ITEM',
            width: item,
            height: item,
            onDown: game.useItem,
          ),
          const SizedBox(height: 12),
          _TouchButton(
            label: 'CUT',
            width: cut,
            height: cut,
            fontSize: 20,
            onDown: () => game.setTouchCut(true),
            onUp: () => game.setTouchCut(false),
          ),
        ],
      ),
    );
  }
}

/// Shown over the game in portrait on a touch screen; the game is paused
/// behind it.
class RotatePrompt extends StatelessWidget {
  const RotatePrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.letterbox,
      child: Center(
        child: Text(
          'Rotate your device\nto landscape',
          textAlign: TextAlign.center,
          style: _labelStyle.copyWith(fontSize: 24),
        ),
      ),
    );
  }
}
