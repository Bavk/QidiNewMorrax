import '../geometry/source_polygon.dart';
import 'source_arachne_wall_tool_paths.dart';
import 'source_arachne_wall_tool_paths_prepare.dart';
import 'source_clipper1_miter_offset.dart';

/// Source-order `WallToolPaths::generate()` preparation with the pinned
/// Clipper1 numerical path wherever the represented per-path executor is exact.
///
/// One positive convex contour is fully handled without Clipper2. A validated
/// safe orthogonal concave positive-contour subset now also uses exact compiled-
/// oracle Clipper1 positive/negative `Execute()` cleanup. Multiple convex paths,
/// including CW holes, use exact Clipper1 per-path `raw_offset()` arithmetic and
/// cleanup; only the final cross-path NonZero union still delegates to the
/// existing Clipper2 compatibility adapter. General concave topology-changing
/// execution therefore remains an explicit differential validation seam. All
/// post-offset cleanup stages are the direct ports already hosted by
/// [SourceArachneWallToolPathsPrepare2].
class SourceArachneWallToolPathsPrepareExact2 {
  const SourceArachneWallToolPathsPrepareExact2._();

  static SourceArachnePreparedOutline2 prepare(
    SourceArachneWallToolPathsState2 state, {
    bool enableHoleCompensation = false,
    Iterable<int> holeIndices = const <int>[],
  }) {
    final originalOutlineSize = state.outline.length;
    var outlineSizeChange = false;

    var prepared = offsetPolygons(
      state.outline,
      -SourceArachneWallToolPathsPreprocess2.epsilonOffset.toDouble(),
    );
    prepared = offsetPolygons(
      prepared,
      (SourceArachneWallToolPathsPreprocess2.epsilonOffset * 2).toDouble(),
    );
    prepared = offsetPolygons(
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

  /// Pinned Clipper1 miter arithmetic for the represented exact source paths.
  ///
  /// - one positive convex contour returns the exact Clipper1 result directly;
  /// - one safe simple orthogonal concave positive contour uses the exact
  ///   compiled-oracle positive/negative Clipper1 `Execute()` subset;
  /// - several convex paths (CCW contours and/or CW holes) execute exact
  ///   per-path Clipper1 offset/sign/orientation semantics, then use Clipper2
  ///   only for the still-open final `clipper_union(raw_offset(...))` seam;
  /// - topology-changing or non-orthogonal concave paths fall back to the prior
  ///   compatibility implementation until full Clipper1 boolean cleanup is
  ///   ported.
  static List<SourcePolygon2> offsetPolygons(
    Iterable<SourcePolygon2> polygons,
    double delta,
  ) {
    final values = List<SourcePolygon2>.of(polygons);
    if (values.isEmpty) return const <SourcePolygon2>[];

    if (values.length == 1 &&
        SourceClipper1MiterOffset2.supports(values.single, delta)) {
      final offset = SourceClipper1MiterOffset2.offset(values.single, delta);
      if (offset.points.length < 3 || offset.signedArea <= 0) {
        return const <SourcePolygon2>[];
      }
      return List.unmodifiable([offset]);
    }

    if (values.length == 1 &&
        SourceClipper1MiterOffset2
            .supportsSimpleOrthogonalConcavePositiveContour(
          values.single,
          delta,
        )) {
      final offset = SourceClipper1MiterOffset2
          .offsetSimpleOrthogonalConcavePositiveContour(
        values.single,
        delta,
      );
      if (offset.points.length < 3 || offset.signedArea <= 0) {
        return const <SourcePolygon2>[];
      }
      return List.unmodifiable([offset]);
    }

    if (values.length > 1 &&
        values.every(
          (polygon) => SourceClipper1MiterOffset2.supportsConvexSourcePath(
            polygon,
            delta,
          ),
        )) {
      final perPath = <SourcePolygon2>[];
      for (final polygon in values) {
        final offset = SourceClipper1MiterOffset2.offsetConvexSourcePath(
          polygon,
          delta,
        );
        if (offset.points.length >= 3 && offset.signedArea != 0) {
          perPath.add(offset);
        }
      }
      if (perPath.isEmpty) return const <SourcePolygon2>[];
      return SourceArachneWallToolPathsPrepare2.unionNonZero(perPath);
    }

    return SourceArachneWallToolPathsPrepare2.offsetPolygons(values, delta);
  }
}
