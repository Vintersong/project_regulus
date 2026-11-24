import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the best score between runs, in a small text file. Failures are
/// swallowed: a missing or unwritable file just means no saved best.
class ScoreStore {
  ScoreStore({String? path}) : _path = path ?? _defaultPath();

  final String _path;
  static const _webKey = 'regulus_best';

  Future<int> load() async {
    try {
      if (kIsWeb) {
        return (await SharedPreferences.getInstance()).getInt(_webKey) ?? 0;
      }
      final file = File(_path);
      if (!await file.exists()) return 0;
      return int.tryParse((await file.readAsString()).trim()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> save(int score) async {
    try {
      if (kIsWeb) {
        await (await SharedPreferences.getInstance()).setInt(_webKey, score);
        return;
      }
      final file = File(_path);
      await file.parent.create(recursive: true);
      await file.writeAsString('$score');
    } catch (_) {
      // Not being able to save a high score must never break the game.
    }
  }

  static String _defaultPath() {
    if (kIsWeb) return ''; // unused: the browser's storage is keyed instead
    final env = Platform.environment;
    final base = env['APPDATA'] ?? env['HOME'] ?? Directory.systemTemp.path;
    final sep = Platform.pathSeparator;
    return '$base${sep}Regulus${sep}highscore.txt';
  }
}

/// Remembers whether the tutorial has been done (or skipped), so it only runs
/// by itself on the first launch. Same rules as [ScoreStore]: a file that
/// can't be read or written just means "not done yet".
class ProgressStore {
  ProgressStore({String? path}) : _path = path ?? _defaultPath();

  final String _path;
  static const _webKey = 'regulus_tutorial_done';

  Future<bool> tutorialDone() async {
    try {
      if (kIsWeb) {
        return (await SharedPreferences.getInstance()).getBool(_webKey) ?? false;
      }
      return await File(_path).exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> markTutorialDone() async {
    try {
      if (kIsWeb) {
        await (await SharedPreferences.getInstance()).setBool(_webKey, true);
        return;
      }
      final file = File(_path);
      await file.parent.create(recursive: true);
      await file.writeAsString('done');
    } catch (_) {
      // Worst case the tutorial offers itself again next launch.
    }
  }

  static String _defaultPath() {
    if (kIsWeb) return ''; // unused: the browser's storage is keyed instead
    final env = Platform.environment;
    final base = env['APPDATA'] ?? env['HOME'] ?? Directory.systemTemp.path;
    final sep = Platform.pathSeparator;
    return '$base${sep}Regulus${sep}tutorial_done';
  }
}
