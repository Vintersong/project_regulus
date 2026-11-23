import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../config.dart';
import '../grid/claim_grid.dart';
import '../grid/session.dart';
import '../palette.dart';

/// Draws the claim grid.
///
/// Captured ground is drawn by the shine shader when it loads (a plate with a
/// foil sheen, masked by the claim grid), or as a flat fill if it can't. Edge
/// cells are the walkable network: the part the player can reach is bright
/// and glowing; edge walled off inside captured ground is dim, because it
/// looks like a path but can't be walked.
class ClaimGridComponent extends PositionComponent {
  ClaimGridComponent(this.session)
      : grid = session.grid,
        super(
          position: Vector2(GameConfig.playfieldLeft, GameConfig.playfieldTop),
          size: Vector2(GameConfig.playfieldWidth, GameConfig.playfieldHeight),
        );

  final GameSession session;
  final ClaimGrid grid;

  // --- shine shader -------------------------------------------------------

  ui.FragmentShader? _shader;

  /// Every captured cell as one path, rebuilt only when the claim changes.
  /// The shader fills it, so it only shows over captured ground.
  ui.Path? _claimedPath;
  int _pathRevision = -1;
  double _time = 0;

  // --- edges --------------------------------------------------------------

  ui.Picture? _edgePicture;
  Uint8List? _reach;
  int _edgeRevision = -1;

  final ui.Paint _claimedFlat = ui.Paint()..color = Palette.claimed;

  // The plate's colours, eased toward the current layer's look so a descent
  // crossfades instead of snapping.
  ui.Color _plate = Palette.layers.first.plate;
  ui.Color _ink = Palette.layers.first.ink;
  final ui.Paint _trail = ui.Paint()..color = Palette.cut;
  final ui.Paint _trailOutline = ui.Paint()..color = Palette.letterbox;

  @override
  Future<void> onLoad() async {
    try {
      final program =
          await ui.FragmentProgram.fromAsset('assets/shaders/shine.frag');
      _shader = program.fragmentShader();
    } catch (e) {
      // Fall back to a flat fill rather than lose the game over a shader.
      debugPrint('Shine shader unavailable, using flat fill: $e');
    }
  }

  @override
  void onRemove() {
    _edgePicture?.dispose();
    _shader?.dispose();
  }

  @override
  void update(double dt) {
    _time += dt;
    final look = Palette.forLayer(session.layer);
    final k = min(1.0, dt * GameConfig.layerFadeRate);
    _plate = ui.Color.lerp(_plate, look.plate, k)!;
    _ink = ui.Color.lerp(_ink, look.ink, k)!;
    _claimedFlat.color = _plate;
    if (_pathRevision != grid.claimedRevision) {
      _pathRevision = grid.claimedRevision;
      _claimedPath = _buildClaimedPath();
    }
  }

  /// All captured cells as horizontal runs in one path.
  ui.Path _buildClaimedPath() {
    const s = GameConfig.cellSize;
    final path = ui.Path();
    for (var r = 0; r < grid.rows; r++) {
      var c = 0;
      while (c < grid.columns) {
        if (grid.stateAt(c, r) != CellState.claimed) {
          c++;
          continue;
        }
        final start = c;
        while (c < grid.columns && grid.stateAt(c, r) == CellState.claimed) {
          c++;
        }
        path.addRect(ui.Rect.fromLTWH(start * s, r * s, (c - start) * s, s));
      }
    }
    return path;
  }

  // --- drawing ------------------------------------------------------------

  @override
  void render(ui.Canvas canvas) {
    _renderClaimed(canvas);
    _renderEdges(canvas);
    _renderTrail(canvas);
  }

  void _renderClaimed(ui.Canvas canvas) {
    final path = _claimedPath;
    if (path == null) return;
    final shader = _shader;
    if (shader == null) {
      canvas.drawPath(path, _claimedFlat); // no shader: flat fill
      return;
    }

    final t = canvas.getTransform();
    shader
      ..setFloat(0, size.x)
      ..setFloat(1, size.y)
      ..setFloat(2, _time)
      ..setFloat(3, (session.walker.column + 0.5) / grid.columns)
      ..setFloat(4, (session.walker.row + 0.5) / grid.rows)
      // The shader's coordinates can be local or device pixels depending on
      // the renderer; if device, the canvas transform undoes it.
      ..setFloat(5, _deviceSpace ? t[12] : 0)
      ..setFloat(6, _deviceSpace ? t[13] : 0)
      ..setFloat(7, _deviceSpace ? t[0] : 1)
      ..setFloat(8, _plate.r)
      ..setFloat(9, _plate.g)
      ..setFloat(10, _plate.b)
      ..setFloat(11, _ink.r)
      ..setFloat(12, _ink.g)
      ..setFloat(13, _ink.b);
    canvas.drawPath(path, ui.Paint()..shader = shader);
  }

  /// Whether the shader reports device pixels rather than local coordinates.
  /// Set from the first on-screen check; see [GameConfig.shaderDeviceSpace].
  bool get _deviceSpace => GameConfig.shaderDeviceSpace;

  void _renderEdges(ui.Canvas canvas) {
    // Rebuild only when edge cells changed, or the player moved onto a
    // network the cached reachability doesn't know about.
    final w = session.walker;
    final seed = grid.index(w.edgeColumn, w.edgeRow);
    final reach = _reach;
    if (_edgePicture == null ||
        _edgeRevision != grid.edgeRevision ||
        reach == null ||
        reach[seed] == 0) {
      _edgeRevision = grid.edgeRevision;
      _reach = grid.reachableEdges(w.edgeColumn, w.edgeRow);
      _edgePicture?.dispose();
      _edgePicture = _buildEdgePicture(_reach!);
    }
    canvas.drawPicture(_edgePicture!);
  }

  ui.Picture _buildEdgePicture(Uint8List reach) {
    const s = GameConfig.cellSize;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final glow = ui.Paint()
      ..color = Palette.line.withValues(alpha: 0.45)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
    final bright = ui.Paint()..color = Palette.line;
    final dim = ui.Paint()..color = Palette.line.withValues(alpha: 0.2);

    // One path per look, drawn once each. A blurred draw is a full blur pass,
    // and this picture is replayed every frame, so a blur per run of cells
    // got slower with every cut. Three draws cost the same however many
    // lines there are.
    final glowPath = ui.Path();
    final brightPath = ui.Path();
    final dimPath = ui.Path();

    for (var r = 0; r < grid.rows; r++) {
      var c = 0;
      while (c < grid.columns) {
        if (grid.stateAt(c, r) != CellState.edge) {
          c++;
          continue;
        }
        // A run of edge cells that are all reachable, or all not.
        final live = reach[grid.index(c, r)] == 1;
        final start = c;
        while (c < grid.columns &&
            grid.stateAt(c, r) == CellState.edge &&
            (reach[grid.index(c, r)] == 1) == live) {
          c++;
        }
        final rect = ui.Rect.fromLTWH(start * s, r * s, (c - start) * s, s);
        if (live) {
          glowPath.addRect(rect.inflate(2));
          brightPath.addRect(rect);
        } else {
          dimPath.addRect(rect);
        }
      }
    }
    canvas
      ..drawPath(dimPath, dim)
      ..drawPath(glowPath, glow)
      ..drawPath(brightPath, bright);
    return recorder.endRecording();
  }

  void _renderTrail(ui.Canvas canvas) {
    const s = GameConfig.cellSize;
    final element = session.effects.dominant;
    _trail.color = element == null ? Palette.cut : Palette.forElement(element);

    final path = ui.Path();
    final outline = ui.Path();
    for (final i in session.walker.trailCells) {
      final x = grid.columnOf(i) * s;
      final y = grid.rowOf(i) * s;
      path.addRect(ui.Rect.fromLTWH(x, y, s, s));
      outline.addRect(ui.Rect.fromLTWH(x - 1.5, y - 1.5, s + 3, s + 3));
    }
    // The open line is the thing that can kill you: it glows, in amber while
    // you can still back out and red once you are committed.
    final w = session.walker;
    if (w.isDrawing) {
      final warn = w.canRetract ? Palette.warn : Palette.enemy;
      canvas.drawPath(
        path,
        ui.Paint()
          ..color = warn.withValues(alpha: 0.55)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 8
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5),
      );
    }
    // Dark rim first, so the line reads against any ground behind it.
    canvas
      ..drawPath(outline, _trailOutline)
      ..drawPath(path, _trail);
  }
}
