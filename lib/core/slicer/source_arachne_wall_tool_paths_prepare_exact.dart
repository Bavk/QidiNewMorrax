import '../geometry/source_polygon.dart';
import 'source_arachne_wall_tool_paths.dart';
import 'source_arachne_wall_tool_paths_prepare.dart';
import 'source_clipper1_miter_offset.dart';

/// Source-order `WallToolPaths::generate()` preparation with the exact pinned
/// Clipper1 numerical path for simple convex outlines.
///
/// Concave/multi-polygon offset execution still delegates to the existing
/// Clipper2 compatibility adapter and therefore remains an explicit differential
/// validation seam. All post-offset cleanup stages are the direct ports already
/// hosted by [SourceArachneWallToolPathsPrepare2].
class SourceArachneWallToolPathsPrepareExact2 {
  const SourceArachneWallToolPathsPrepareExact2._();

  static SourceArachnePreparedOutline2 prepare(
    SourceArachneWallToolPathsState2 state, {
    bool enableHoleCompensation = false,
    Iterable<int> holeIndices = const <int>[],
  }) {
    final originalOutlineSize = state.outline.length;
    var outlineSizeChange = false;

    var prepared = _offset(
      state.outline,
      -SourceArachneWallToolPathsPreprocess2.epsilonOffset.toDouble(),
    );
    prepared = _offset(
      prepared,
      (SourceArachneWallToolPathsPreprocess2.epsilonOffset * 2).toDouble(),
    );
    prepared = _offset(
      prepared,
      -SourceArachneWallToolPathsPreprocess2.epsilonOffset.toDouble(),
    );
    outlineSizeChange |= prepared.length != originalOutlineSize;

    void updateSizeChange() {
      outlineSizeChange |= prepared.length != originalOutlineSize;
    }

    prepared = SourceArachneWallToolPathsPreprocess2.simplifyPolygons(
      prepared,
      smallestLineSegment:
          SourceArachneWallToolPathsPreprocess2.meshfixMaximumResolution,
      allowedErrorDistance:
          SourceArachneWallToolPathsPreprocess2.meshfixMaximumDeviation,
    );
    updateSizeChange();

    prepared = SourceArachneWallToolPathsPrepare2.fixSelfIntersections(
      prepared,
      SourceArachneWallToolPathsPreprocess2.epsilonOffset,
    );
    updateSizeChange();

    prepared =
        SourceArachneWallToolPathsPrepare2.removeDegenerateVertices(prepared);
    updateSizeChange();

    prepared = SourceArachneWallToolPathsPrepare2.removeColinearEdges(
      prepared,
      maxDeviationAngle: 0.005,
    );
    updateSizeChange();

    prepared = SourceArachneWallToolPathsPrepare2.fixSelfIntersections(
      prepared,
      SourceArachneWallToolPathsPreprocess2.epsilonOffset,
    );
    updateSizeChange();

    prepared =
        SourceArachneWallToolPathsPrepare2.removeDegenerateVertices(prepared);
    updateSizeChange();

    prepared = SourceArachneWallToolPathsPrepare2.removeSmallAreas(
      prepared,
      state.smallAreaLength * state.smallAreaLength,
      removeHoles: false,
    );
    updateSizeChange();

    prepared = SourceArachneWallToolPathsPrepare2.unionNonZero(prepared);
    updateSizeChange();

    final totalSignedArea = prepared.fold<double>(
      0,
      (sum, polygon) => sum + polygon.signedArea,
    );

    return SourceArachnePreparedOutline2(
      preparedOutline: prepared,
      outlineSizeChange: outlineSizeChange,
      totalSignedArea: totalSignedArea,
      applyHoleCompensation:
          enableHoleCompensation && !outlineSizeChange,
      holeIndices: holeIndices,
    );
  }

  static List<SourcePolygon2> _offset(
    Iterable<SourcePolygon2> polygons,
    double delta,
  ) {
    final values = List<SourcePolygon2>.of(polygons);
    if (values.length == 1 &&
        SourceClipper1MiterOffset2.supports(values.single, delta)) {
      return List.unmodifiable([
        SourceClipper1MiterOffset2.offset(values.single, delta),
      ]);
    }
    return SourceArachneWallToolPathsPrepare2.offsetPolygons(values, delta);
  }
}
