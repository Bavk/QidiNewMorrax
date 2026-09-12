import '../geometry/source_polygon.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_wall_tool_paths.dart';
import 'source_arachne_wall_tool_paths_generate.dart';

/// Stateful source-shaped facade for pinned `Arachne::WallToolPaths` getters.
///
/// `generate()` deliberately leaves `toolpaths_generated == false` on its two
/// early-return paths. Consequently repeated getter calls may regenerate; this
/// class preserves that behavior instead of memoizing every attempt.
class SourceArachneWallToolPathsFacade2 {
  SourceArachneWallToolPathsFacade2(this.state);

  final SourceArachneWallToolPathsState2 state;

  bool _enableHoleCompensation = false;
  List<int> _holeIndices = const <int>[];
  SourceArachneWallToolPathsGenerated2? _latest;

  /// Direct source `EnableHoleCompensation`: assignment only, no generation.
  void enableHoleCompensation(bool enable, Iterable<int> holeIndices) {
    _enableHoleCompensation = enable;
    _holeIndices = List<int>.unmodifiable(holeIndices);
  }

  List<List<SourceArachneExtrusionLine2>> getToolPaths() {
    if (_latest?.toolpathsGenerated != true) {
      _generate();
    }
    return _latest!.toolpaths;
  }

  List<SourcePolygon2> getInnerContour() {
    if (_latest?.toolpathsGenerated != true && state.insetCount > 0) {
      _generate();
    } else if (state.insetCount == 0) {
      // Pinned getter returns the constructor's `outline` directly.
      return state.outline;
    }
    return _latest?.innerContour ?? const <SourcePolygon2>[];
  }

  List<SourcePolygon2> getFirstWallContour() {
    if (_latest?.toolpathsGenerated != true && state.insetCount > 0) {
      _generate();
    } else if (state.insetCount == 0) {
      // Pinned source returns global `EmptyPolygons` here.
      return const <SourcePolygon2>[];
    }
    return _latest?.firstWallContour ?? const <SourcePolygon2>[];
  }

  bool get toolpathsGenerated => _latest?.toolpathsGenerated ?? false;

  SourceArachneWallToolPathsGenerated2? get latest => _latest;

  void _generate() {
    _latest = SourceArachneWallToolPathsGenerate2.generate(
      state,
      enableHoleCompensation: _enableHoleCompensation,
      holeIndices: _holeIndices,
    );
  }
}
