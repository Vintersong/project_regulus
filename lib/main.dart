import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'game/palette.dart';
import 'game/regulus_game.dart';

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
      home: ColoredBox(
        color: Palette.letterbox,
        // .controlled keeps one game instance across widget rebuilds.
        child: GameWidget<RegulusGame>.controlled(gameFactory: RegulusGame.new),
      ),
    );
  }
}
