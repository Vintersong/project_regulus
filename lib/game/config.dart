/// Fixed logical layout. The camera letterboxes this to any window size.
abstract final class GameConfig {
  // Logical view (16:10 landscape).
  static const double viewWidth = 1280;
  static const double viewHeight = 800;

  // Claim grid. Each cell is one unit of capturable territory.
  static const double cellSize = 5;
  static const int gridColumns = 240;
  static const int gridRows = 144;

  static const double playfieldWidth = gridColumns * cellSize; // 1200
  static const double playfieldHeight = gridRows * cellSize; // 720
  static const double playfieldLeft = (viewWidth - playfieldWidth) / 2;
  static const double playfieldTop = (viewHeight - playfieldHeight) / 2;

  // Share of the field to capture to clear a level (Qix used 75%).
  static const double captureTarget = 0.75;
}
