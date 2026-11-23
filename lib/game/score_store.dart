import 'dart:io';

/// Keeps the best score between runs, in a small text file. Failures are
/// swallowed: a missing or unwritable file just means no saved best.
class ScoreStore {
  ScoreStore({String? path}) : _path = path ?? _defaultPath();

  final String _path;

  Future<int> load() async {
    try {
      final file = File(_path);
      if (!await file.exists()) return 0;
      return int.tryParse((await file.readAsString()).trim()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> save(int score) async {
    try {
      final file = File(_path);
      await file.parent.create(recursive: true);
      await file.writeAsString('$score');
    } catch (_) {
      // Not being able to save a high score must never break the game.
    }
  }

  static String _defaultPath() {
    final env = Platform.environment;
    final base = env['APPDATA'] ?? env['HOME'] ?? Directory.systemTemp.path;
    final sep = Platform.pathSeparator;
    return '$base${sep}Regulus${sep}highscore.txt';
  }
}
