import 'package:flutter/foundation.dart'
    show TargetPlatform, ValueNotifier, defaultTargetPlatform;

/// Whether the player is on a touch screen, so the on-screen controls show and
/// the on-screen text talks about buttons instead of keys.
///
/// It starts true on phones and tablets, turns true on the first touch (this
/// catches iPads that pose as desktops), and turns false on the first key
/// press (a keyboard is plugged in).
abstract final class InputMode {
  static final ValueNotifier<bool> touch = ValueNotifier<bool>(
    defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS,
  );

  static bool get isTouch => touch.value;

  /// Rewrites on-screen copy that names keys, for touch players. The text
  /// itself is written once, for the keyboard; this swaps in the buttons.
  static String adapt(String text) {
    if (!isTouch) return text;
    return text
        .replaceAll('the ARROW KEYS or WASD', 'the D-PAD')
        .replaceAll('Hold SHIFT (or Z)', 'Hold CUT')
        .replaceAll('Press SPACE', 'Tap ITEM')
        .replaceAll('    T: tutorial', '')
        .replaceAll('Space: ', 'Tap: ');
  }
}
