import 'package:flutter_test/flutter_test.dart';
import 'package:project_regulus/game/config.dart';

void main() {
  test('playfield is centred inside the logical view', () {
    expect(
      GameConfig.playfieldLeft * 2 + GameConfig.playfieldWidth,
      GameConfig.viewWidth,
    );
    expect(
      GameConfig.playfieldTop * 2 + GameConfig.playfieldHeight,
      GameConfig.viewHeight,
    );
  });
}
