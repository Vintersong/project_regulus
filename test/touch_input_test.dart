import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_regulus/game/grid/claim_grid.dart';
import 'package:project_regulus/game/grid/direction.dart';
import 'package:project_regulus/game/grid/session.dart';
import 'package:project_regulus/game/input_mode.dart';
import 'package:project_regulus/game/tutorial.dart';
import 'package:project_regulus/ui/touch_controls.dart';

void main() {
  tearDown(() => InputMode.touch.value = false);

  group('InputMode.adapt', () {
    test('leaves keyboard text alone', () {
      InputMode.touch.value = false;
      expect(
        InputMode.adapt('Press SPACE to use it.'),
        'Press SPACE to use it.',
      );
    });

    test('names the buttons on touch', () {
      InputMode.touch.value = true;
      expect(
        InputMode.adapt('Move with the ARROW KEYS or WASD.'),
        'Move with the D-PAD.',
      );
      expect(InputMode.adapt('Hold SHIFT (or Z) and go'), 'Hold CUT and go');
      expect(InputMode.adapt('Press SPACE to use it.'), 'Tap ITEM to use it.');
      expect(
        InputMode.adapt('Space: play again    T: tutorial'),
        'Tap: play again',
      );
    });

    test('no tutorial step still mentions a key on touch', () {
      InputMode.touch.value = true;
      final tutorial = Tutorial(
        GameSession(
          grid: ClaimGrid(columns: 60, rows: 40),
          random: Random(1),
        ),
      );
      for (final step in tutorial.steps) {
        final text = InputMode.adapt(step.text);
        for (final key in ['SPACE', 'SHIFT', 'ARROW', 'WASD', 'ESC']) {
          expect(text, isNot(contains(key)), reason: step.text);
        }
      }
    });
  });

  group('padDirection', () {
    const r = 100.0;

    test('the dead zone in the middle holds nothing', () {
      expect(padDirection(const Offset(5, -5), r, null), isNull);
    });

    test('picks the dominant axis', () {
      expect(padDirection(const Offset(60, 10), r, null), Direction.right);
      expect(padDirection(const Offset(-60, 10), r, null), Direction.left);
      expect(padDirection(const Offset(10, 60), r, null), Direction.down);
      expect(padDirection(const Offset(10, -60), r, null), Direction.up);
    });

    test('a thumb on the diagonal keeps the direction it had', () {
      const diagonal = Offset(50, 50);
      expect(padDirection(diagonal, r, Direction.right), Direction.right);
      expect(padDirection(diagonal, r, Direction.down), Direction.down);
    });

    test('and switches once it is clearly on the other axis', () {
      expect(padDirection(const Offset(20, 60), r, Direction.right),
          Direction.down);
      expect(padDirection(const Offset(60, 20), r, Direction.down),
          Direction.right);
    });
  });
}
