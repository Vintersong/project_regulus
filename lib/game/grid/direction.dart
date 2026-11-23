/// The four directions the single input layer maps every device to.
enum Direction {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0);

  const Direction(this.dc, this.dr);

  /// Column and row offset of one step.
  final int dc;
  final int dr;
}
