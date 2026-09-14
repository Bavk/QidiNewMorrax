import '../geometry/source_polygon.dart';
import 'source_arachne_wall_tool_paths.dart';
import 'source_arachne_wall_tool_paths_prepare.dart';
import 'source_clipper1_miter_offset.dart';
import 'source_clipper1_negative_concave_execute.dart';
import 'source_clipper1_noninteracting_union.dart';
import 'source_clipper1_orthogonal_execute.dart';
import 'source_clipper1_positive_concave_execute.dart';

/// Source-order `WallToolPaths::generate()` preparation with the pinned
/// Clipper1 numerical path wherever the represented executor is exact.
///
/// One positive convex contour is fully handled without Clipper2. A validated
/// safe orthogonal concave positive-contour subset uses direct compiled-oracle
/// Clipper1 cleanup, and the represented rectilinear executor also covers
/// topology-changing orthogonal results that stay within positive contours,
/// including one input splitting into multiple disconnected contours. First
/// non-orthogonal positive/negative concave subsets preserve isolated source
/// spike cleanup proved by exact pinned ELF V-notch oracles. Multiple convex
/// paths, including CW holes, use exact Clipper1 per-path arithmetic; a
/// conservative NonZero-union subset bypasses Clipper2 when those offset
/// boundaries do not interact. Intersecting/deeper-nested cross-path unions,
/// multi-reflex/nonlocal non-orthogonal cleanup and orthogonal hole/point-touch
/// ambiguity remain explicit compatibility seams. All post-offset cleanup stages
/// are the direct ports already hosted by [SourceArachneWallToolPathsPrepare2].
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
  /// - one safe simple orthogonal concave positive contour uses the direct
  ///   compiled-oracle positive/negative Clipper1 cleanup subset;
  /// - one orthogonal contour whose cleanup yields one or more disconnected
  ///   positive contours uses the exact rectilinear `Execute()` subset;
  /// - one non-orthogonal positive contour with isolated miter-only concave
  ///   spikes uses the exact local positive-union cleanup subset;
  /// - one non-orthogonal negative contour with exactly one reflex turn and a
  ///   simple contained result uses the exact local pftNegative cleanup subset;
  /// - several convex paths (CCW contours and/or CW holes) execute exact
  ///   per-path Clipper1 offset/sign/orientation semantics. If their resulting
  ///   boundaries remain noninteracting, the represented NonZero winding subset
  ///   returns them without Clipper2; otherwise only the final union falls back;
  /// - multi-reflex/nonlocal non-orthogonal cleanup and orthogonal hole/point-
  ///   touch ambiguity stay on the compatibility path until independently
  ///   represented.
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

    if (values.length == 1 &&
        SourceClipper1OrthogonalExecute2.supportsPositiveContours(
          values.single,
          delta,
        )) {
      return SourceClipper1OrthogonalExecute2.offsetPositiveContours(
        values.single,
        delta,
      );
    }

    if (values.length == 1 &&
        SourceClipper1PositiveConcaveExecute2.supports(
          values.single,
          delta,
        )) {
      return List.unmodifiable([
        SourceClipper1PositiveConcaveExecute2.offset(values.single, delta),
      ]);
    }

    if (values.length == 1 &&
        SourceClipper1NegativeConcaveExecute2.supports(
          values.single,
          delta,
        )) {
      return List.unmodifiable([
        SourceClipper1NegativeConcaveExecute2.offset(values.single, delta),
      ]);
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
      if (SourceClipper1NonInteractingUnion2.supports(perPath)) {
        return SourceClipper1NonInteractingUnion2.union(perPath);
      }
      return SourceArachneWallToolPathsPrepare2.unionNonZero(perPath);
    }

    return SourceArachneWallToolPathsPrepare2.offsetPolygons(values, delta);
  }
}
