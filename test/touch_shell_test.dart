import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_regulus/game/grid/direction.dart';
import 'package:project_regulus/game/input_mode.dart';
import 'package:project_regulus/game/regulus_game.dart';
import 'package:project_regulus/main.dart';
import 'package:project_regulus/ui/touch_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => InputMode.touch.value = false);

  Future<RegulusGame> boot(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const RegulusApp());
    await tester.pump(const Duration(milliseconds: 200));
    final widget = tester.widget<GameWidget<RegulusGame>>(
      find.byType(GameWidget<RegulusGame>),
    );
    return widget.game!;
  }

  Future<void> shutDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('landscape touch: the pad and buttons drive the game', (
    tester,
  ) async {
    InputMode.touch.value = true;
    final game = await boot(tester, const Size(1600, 720));

    expect(find.byType(DPad), findsOneWidget);
    expect(find.text('CUT'), findsOneWidget);
    expect(find.text('ITEM'), findsOneWidget);

    // CUT is held only while the finger is down.
    expect(game.session.canStartCut, isFalse);
    final cut = await tester.startGesture(tester.getCenter(find.text('CUT')));
    expect(game.session.canStartCut, isTrue);
    await cut.up();
    expect(game.session.canStartCut, isFalse);

    // The pad follows the thumb, and lets go when it lifts.
    final pad = tester.getCenter(find.byType(DPad));
    final thumb = await tester.startGesture(pad + const Offset(40, 0));
    expect(game.heldDirection, Direction.right);
    await thumb.moveTo(pad + const Offset(0, -40));
    expect(game.heldDirection, Direction.up);
    await thumb.up();
    expect(game.heldDirection, isNull);

    // Both thumbs at once.
    final left = await tester.startGesture(pad + const Offset(-40, 0));
    final right = await tester.startGesture(
      tester.getCenter(find.text('CUT')),
    );
    expect(game.heldDirection, Direction.left);
    expect(game.session.canStartCut, isTrue);
    await left.up();
    await right.up();

    await shutDown(tester);
  });

  testWidgets('portrait touch: rotate prompt, no controls, game paused', (
    tester,
  ) async {
    InputMode.touch.value = true;
    final game = await boot(tester, const Size(720, 1280));
    await tester.pump();

    expect(find.byType(RotatePrompt), findsOneWidget);
    expect(find.byType(DPad), findsNothing);
    expect(game.paused, isTrue);

    await shutDown(tester);
  });

  testWidgets('keyboard play shows no touch controls', (tester) async {
    InputMode.touch.value = false;
    await boot(tester, const Size(1600, 720));

    expect(find.byType(DPad), findsNothing);
    expect(find.text('CUT'), findsNothing);

    await shutDown(tester);
  });

  testWidgets('a key press hides the touch controls', (tester) async {
    InputMode.touch.value = true;
    await boot(tester, const Size(1600, 720));
    expect(find.byType(DPad), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pump();
    expect(InputMode.touch.value, isFalse);
    expect(find.byType(DPad), findsNothing);

    await shutDown(tester);
  });
}
