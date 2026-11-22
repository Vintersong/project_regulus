import 'package:flame/game.dart';
import 'package:flutter/material.dart';

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
    return MaterialApp(
      title: 'Regulus',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Palette.letterbox,
        // .controlled keeps one game instance across widget rebuilds.
        body: GameWidget<RegulusGame>.controlled(gameFactory: RegulusGame.new),
      ),
    );
  }
}
